#! /usr/bin/perl

use strict;
use warnings;
use Digest::SHA();
use MIME::Base64();
use Test::More;
use Cwd();
use Firefox::Marionette qw(:all);
use Compress::Zlib();
use Config;
use HTTP::Daemon();
use HTTP::Status();
use HTTP::Response();
use IO::Socket::SSL();

my $segv_detected;
my $at_least_one_success;
my $terminated;

my $test_time_limit = 90;

if (($^O eq 'MSWin32') || ($^O eq 'cygwin')) {
} elsif ($> == 0) { # see RT#131304
       my $current = $ENV{HOME};
       my $correct = (getpwuid($>))[7];
       if ($current eq $correct) {
       } else {
               $ENV{HOME} = $correct;
               diag("Running as root.  Resetting HOME environment variable from $current to $ENV{HOME}");
               diag("Could be running in an environment where sudo does not reset the HOME environment variable, such as ubuntu");
       }
       if ( exists $ENV{XAUTHORITY} ) {    # see GH#1
               delete $ENV{XAUTHORITY};
               warn "Running as root.  Deleting the XAUTHORITY environment variable\n";
       }
}

my @sig_nums  = split q[ ], $Config{sig_num};
my @sig_names = split q[ ], $Config{sig_name};
my %signals_by_name;
my $idx = 0;
foreach my $sig_name (@sig_names) {
	$signals_by_name{$sig_name} = $sig_nums[$idx];
	$idx += 1;
}

$SIG{INT} = sub { $terminated = 1; die "Caught an INT signal"; };
$SIG{TERM} = sub { $terminated = 1; die "Caught a TERM signal"; };

sub out_of_time {
	my ($package, $file, $line) = caller 1;
	if (!defined $line) {
		($package, $file, $line) = caller;
	}
	diag("Testing has been running for " . (time - $^T) . " seconds at $file line $line");
	if ($ENV{RELEASE_TESTING}) {
		return;
	} elsif (time - $^T > $test_time_limit) {
		return 1;
	} else {
		return;
	}
}

my $launches = 0;
my $ca_cert_handle;
my $metacpan_ca_cert_handle;

my ($major_version, $minor_version, $patch_version); 
sub start_firefox {
	my ($require_visible, %parameters) = @_;
	if ($terminated) {
		die "Caught a signal";
	}
	if ($ENV{FIREFOX_BINARY}) {
		$parameters{firefox} = $ENV{FIREFOX_BINARY};
		diag("Overriding firefox binary to $parameters{firefox}");
	}
	if (defined $ca_cert_handle) {
		my $certutil = `certutil --help 2>/dev/null`;
		if ($? != 0) {
		} elsif ($launches % 2) {
			diag("Setting trust to list");
			$parameters{trust} = [ '/dev/fd/' . fileno $ca_cert_handle ];
		} else {
			diag("Setting trust to scalar");
			$parameters{trust} = '/dev/fd/' . fileno $ca_cert_handle;
		}
	}
	if ((defined $major_version) && ($major_version >= 61)) {
	} elsif ($parameters{har}) {
		diag("HAR support is not available for Firefox versions less than 61");
		delete $parameters{har};
	}
	if ($parameters{console}) {
		$parameters{console} = 1;
	}
        if (defined $ENV{FIREFOX_NIGHTLY}) {
		$parameters{nightly} = 1;
        }
        if (defined $ENV{FIREFOX_DEVELOPER}) {
		$parameters{developer} = 1;
        }
        if (defined $ENV{FIREFOX_DEBUG}) {
		$parameters{debug} = $ENV{FIREFOX_DEBUG};
        }
	if ($ENV{FIREFOX_HOST}) {
		$parameters{host} = $ENV{FIREFOX_HOST};
		diag("Overriding host to '$parameters{host}'");
		if ($ENV{FIREFOX_USER}) {
			$parameters{user} = $ENV{FIREFOX_USER};
		} elsif (($ENV{FIREFOX_HOST} eq 'localhost') && (!$ENV{FIREFOX_PORT})) {
			if ($launches != 0) {
				diag("Overriding user to 'firefox'");
				$parameters{user} = 'firefox';
			}
		}
		if ((defined $parameters{capabilities}) && (!$parameters{capabilities}->moz_headless())) {
			my $old = $parameters{capabilities};
			my %new = ( moz_headless => 1 );
			if (defined $old->proxy()) {
				$new{proxy} = $old->proxy();
			}
			if (defined $old->moz_use_non_spec_compliant_pointer_origin()) {
				$new{moz_use_non_spec_compliant_pointer_origin} = $old->moz_use_non_spec_compliant_pointer_origin();
			}
			if (defined $old->accept_insecure_certs()) {
				$new{accept_insecure_certs} = $old->accept_insecure_certs();
			}
			if (defined $old->strict_file_interactability()) {
				$new{strict_file_interactability} = $old->strict_file_interactability();
			}
			if (defined $old->unhandled_prompt_behavior()) {
				$new{unhandled_prompt_behavior} = $old->unhandled_prompt_behavior();
			}
			if (defined $old->set_window_rect()) {
				$new{set_window_rect} = $old->set_window_rect();
			}
			if (defined $old->page_load_strategy()) {
				$new{page_load_strategy} = $old->page_load_strategy();
			}
			if (defined $old->moz_webdriver_click()) {
				$new{moz_webdriver_click} = $old->moz_webdriver_click();
			}
			if (defined $old->moz_accessibility_checks()) {
				$new{moz_accessibility_checks} = $old->moz_accessibility_checks();
			}
			if (defined $old->timeouts()) {
				$new{timeouts} = $old->timeouts();
			}
			$parameters{capabilities} = Firefox::Marionette::Capabilities->new(%new);
		}
	}
	if ($ENV{FIREFOX_PORT}) {
		$parameters{port} = $ENV{FIREFOX_PORT};
	}
	if (defined $parameters{capabilities}) {
		if ((defined $major_version) && ($major_version >= 52)) {
		} else {
			delete $parameters{capabilities}->{page_load_strategy};
			delete $parameters{capabilities}->{moz_webdriver_click};
			delete $parameters{capabilities}->{moz_accessibility_checks};
			delete $parameters{capabilities}->{accept_insecure_certs};
			delete $parameters{capabilities}->{strict_file_interactability};
			delete $parameters{capabilities}->{unhandled_prompt_behavior};
			delete $parameters{capabilities}->{set_window_rect};
			delete $parameters{capabilities}->{moz_use_non_spec_compliant_pointer_origin};
		}
	}
	if ($ENV{FIREFOX_VISIBLE}) {
		$require_visible = 1;
		if (!$parameters{visible}) {
			$parameters{visible} = 1;
		}
		if ((defined $parameters{capabilities}) && ($parameters{capabilities}->moz_headless())) {
			my $old = $parameters{capabilities};
			my %new = ( moz_headless => 0 );
			if (defined $old->proxy()) {
				$new{proxy} = $old->proxy();
			}
			if (defined $old->moz_use_non_spec_compliant_pointer_origin()) {
				$new{moz_use_non_spec_compliant_pointer_origin} = $old->moz_use_non_spec_compliant_pointer_origin();
			}
			if (defined $old->accept_insecure_certs()) {
				$new{accept_insecure_certs} = $old->accept_insecure_certs();
			}
			if (defined $old->strict_file_interactability()) {
				$new{strict_file_interactability} = $old->strict_file_interactability();
			}
			if (defined $old->unhandled_prompt_behavior()) {
				$new{unhandled_prompt_behavior} = $old->unhandled_prompt_behavior();
			}
			if (defined $old->set_window_rect()) {
				$new{set_window_rect} = $old->set_window_rect();
			}
			if (defined $old->page_load_strategy()) {
				$new{page_load_strategy} = $old->page_load_strategy();
			}
			if (defined $old->moz_webdriver_click()) {
				$new{moz_webdriver_click} = $old->moz_webdriver_click();
			}
			if (defined $old->moz_accessibility_checks()) {
				$new{moz_accessibility_checks} = $old->moz_accessibility_checks();
			}
			if (defined $old->timeouts()) {
				$new{timeouts} = $old->timeouts();
			}
			$parameters{capabilities} = Firefox::Marionette::Capabilities->new(%new);
		}
		diag("Overriding firefox visibility");
	}
	my $skip_message;
	if ($segv_detected) {
		$skip_message = "Previous SEGV detected.  Trying to shutdown tests as fast as possible";
		return ($skip_message, undef);
	}
	if (out_of_time()) {
		$skip_message = "Running out of time.  Trying to shutdown tests as fast as possible";
		return ($skip_message, undef);
	}
        my $firefox;
	eval {
		$firefox = Firefox::Marionette->new(%parameters);
	};
	my $exception = $@;
	chomp $exception;
	if ($exception) {
		my ($package, $file, $line) = caller;
		my $source = $package eq 'main' ? $file : $package;
		diag("Exception in $source at line $line during new:$exception");
		$skip_message = "SEGV detected.  No need to restart";
	} elsif ((!defined $firefox) && ($major_version < 50)) {
		$skip_message = "Failed to start Firefox:$exception";
	}
	if ($exception =~ /^(Firefox exited with a 11|Firefox killed by a SEGV signal \(11\))/) {
		diag("Caught a SEGV type exception");
		if ($at_least_one_success) {
			$skip_message = "SEGV detected.  No need to restart";
			$segv_detected = 1;
			return ($skip_message, undef);
		} else {
			diag("Running any appliable memory checks");
			if ($^O eq 'linux') {
				diag("grep -r Mem /proc/meminfo");
				diag(`grep -r Mem /proc/meminfo`);
				diag("ulimit -a | grep -i mem");
				diag(`ulimit -a | grep -i mem`);
			} elsif ($^O =~ /bsd/i) {
				diag("sysctl hw | egrep 'hw.(phys|user|real)'");
				diag(`sysctl hw | egrep 'hw.(phys|user|real)'`);
				diag("ulimit -a | grep -i mem");
				diag(`ulimit -a | grep -i mem`);
			}
			my $time_to_recover = 2; # magic number.  No science behind it. Trying to give time to allow O/S to recover.
			diag("About to sleep for $time_to_recover seconds to allow O/S to recover");
			sleep $time_to_recover;
			$firefox = undef;
			eval {
				$firefox = Firefox::Marionette->new(%parameters);
			};
			if ($firefox) {
				$segv_detected = 1;
			} else {
				diag("Caught a second exception:$@");
				$skip_message = "Skip tests that depended on firefox starting successfully:$@";
			}
		}
	} elsif ($exception) {
		if (($^O eq 'MSWin32') || ($^O eq 'cygwin') || ($^O eq 'darwin')) {
			diag("Failed to start in $^O:$exception");
		} else {
			`Xvfb -help 2>/dev/null | grep displayfd`;
			if ($? == 0) {
				if ($require_visible) {
					diag("Failed to start a visible firefox in $^O but Xvfb succeeded:$exception");
				}
			} elsif ($? == 1) {
				my $dbus_output = `dbus-launch 2>/dev/null`;
				if ($? == 0) {
					if ($^O eq 'freebsd') {
						my $mount = `mount`;
						if ($mount =~ /fdescfs/) {
							diag("Failed to start with fdescfs mounted and a working Xvfb and D-Bus:$exception");
						} else {
							$skip_message = "Unable to launch a visible firefox in $^O without fdescfs mounted:$exception";
						}
					} else {
						diag("Failed to start with a working Xvfb and D-Bus:$exception");
					}
					if ($dbus_output =~ /DBUS_SESSION_BUS_PID=(\d+)\b/smx) {
						my ($dbus_pid) = ($1);
						while(kill 0, $dbus_pid) {
							kill $signals_by_name{INT}, $dbus_pid;
							sleep 1;
							waitpid $dbus_pid, POSIX::WNOHANG();
						}
					}
				} else {
					$skip_message = "Unable to launch a visible firefox in $^O with an incorrectly setup D-Bus:$exception";
				}
			} elsif ($require_visible) {
				diag("Failed to start a visible firefox in $^O but Xvfb succeeded:$exception");
				$skip_message = "Skip tests that depended on firefox starting successfully:$exception";
			} elsif ($ENV{DISPLAY}) {
				diag("Failed to start a hidden firefox in $^O with X11 DISPLAY $ENV{DISPLAY} is available:$exception");
				$skip_message = "Skip tests that depended on firefox starting successfully:$exception";
			} else {
				diag("Failed to start a hidden firefox in $^O:$exception");
			}
		}
	}
	if (($firefox) && (!$skip_message)) {
		$launches += 1;
	}
	return ($skip_message, $firefox);
}

umask 0;
my $binary = 'firefox';
if ($ENV{FIREFOX_BINARY}) {
	$binary = $ENV{FIREFOX_BINARY};
} elsif ( $^O eq 'MSWin32' ) {
    my $program_files_key;
    foreach my $possible ( 'ProgramFiles(x86)', 'ProgramFiles' ) {
        if ( $ENV{$possible} ) {
            $program_files_key = $possible;
            last;
        }
    }
    $binary = File::Spec->catfile(
        $ENV{$program_files_key},
        'Mozilla Firefox',
        'firefox.exe'
    );
}
elsif ( $^O eq 'darwin' ) {
    $binary = '/Applications/Firefox.app/Contents/MacOS/firefox';
} elsif ($^O eq 'cygwin') {
            my $windows_x86_firefox_path = "$ENV{PROGRAMFILES} (x86)/Mozilla Firefox/firefox.exe";
            my $windows_firefox_path = "$ENV{PROGRAMFILES}/Mozilla Firefox/firefox.exe";
            if ( -e $windows_x86_firefox_path ) {
		$binary = $windows_x86_firefox_path;
            }
            elsif ( -e $windows_firefox_path ) {
		$binary = $windows_firefox_path;
            }
}
my $version_string = `"$binary" -version`;
diag("Version is $version_string");
if ((exists $ENV{FIREFOX_HOST}) && (defined $ENV{FIREFOX_HOST})) {
	diag("FIREFOX_HOST is $ENV{FIREFOX_HOST}");
}
if ((exists $ENV{FIREFOX_USER}) && (defined $ENV{FIREFOX_USER})) {
	diag("FIREFOX_USER is $ENV{FIREFOX_USER}");
}
if ((exists $ENV{FIREFOX_PORT}) && (defined $ENV{FIREFOX_PORT})) {
	diag("FIREFOX_PORT is $ENV{FIREFOX_PORT}");
}
if ((exists $ENV{FIREFOX_VISIBLE}) && (defined $ENV{FIREFOX_VISIBLE})) {
	diag("FIREFOX_VISIBLE is $ENV{FIREFOX_VISIBLE}");
}
if ($^O eq 'MSWin32') {
} elsif ($^O eq 'darwin') {
} else {
	if (exists $ENV{XAUTHORITY}) {
		diag("XAUTHORITY is $ENV{XAUTHORITY}");
	}
	if (exists $ENV{DISPLAY}) {
		diag("DISPLAY is $ENV{DISPLAY}");
	}
	my $dbus_output = `dbus-launch`;
	if ($? == 0) {
		diag("D-Bus is working");
		if ($dbus_output =~ /DBUS_SESSION_BUS_PID=(\d+)\b/smx) {
			my ($dbus_pid) = ($1);
			while(kill 0, $dbus_pid) {
				kill $signals_by_name{INT}, $dbus_pid;
				sleep 1;
				waitpid $dbus_pid, POSIX::WNOHANG();
			}
		}
	} else {
		diag("D-Bus appears to be broken.  'dbus-launch' was unable to successfully complete:$?");
	}
	if ($^O eq 'freebsd') {
		diag("xorg-vfbserver version is " . `pkg info xorg-vfbserver | perl -nle 'print "\$1" if (/Version\\s+:\\s+(\\S+)\\s*/);'`);
		diag("xauth version is " . `pkg info xauth | perl -nle 'print "\$1" if (/Version\\s+:\\s+(\\S+)\\s*/);'`);
		my $machine_id_path = '/etc/machine-id';
		if (-e $machine_id_path) {
			diag("$machine_id_path is ok");
		} else {
			diag("$machine_id_path has not been created.  Please run 'sudo dbus-uuidgen --ensure=$machine_id_path'");
		}
		print "mount | grep fdescfs\n";
		my $result = `mount | grep fdescfs`;
		if ($result =~ /fdescfs/) {
			diag("fdescfs has been mounted.  /dev/fd/ should work correctly for xvfb/xauth");
		} else {
			diag("It looks like 'sudo mount -t fdescfs fdesc /dev/fd' needs to be executed")
		}
	} elsif ($^O eq 'dragonfly') {
		diag("xorg-vfbserver version is " . `pkg info xorg-vfbserver | perl -nle 'print "\$1" if (/Version\\s+:\\s+(\\S+)\\s*/);'`);
		diag("xauth version is " . `pkg info xauth | perl -nle 'print "\$1" if (/Version\\s+:\\s+(\\S+)\\s*/);'`);
		my $machine_id_path = '/etc/machine-id';
		if (-e $machine_id_path) {
			diag("$machine_id_path is ok");
		} else {
			diag("$machine_id_path has not been created.  Please run 'sudo dbus-uuidgen --ensure=$machine_id_path'");
		}
	} elsif ($^O eq 'linux') {
		if (-f '/etc/debian_version') {
			diag("Debian Version is " . `cat /etc/debian_version`);
		} elsif (-f '/etc/redhat-release') {
			diag("Redhat Version is " . `cat /etc/redhat-release`);
		}
		`dpkg --help >/dev/null 2>/dev/null`;
		if ($? == 0) {	
			diag("Xvfb deb version is " . `dpkg -s Xvfb | perl -nle 'print if s/^Version:[ ]//smx'`);
		} else {
			`rpm --help >/dev/null 2>/dev/null`;
			if (($? == 0) && (-f '/usr/bin/Xvfb')) {
				diag("Xvfb rpm version is " . `rpm -qf /usr/bin/Xvfb`);
			}
		}
	}
}
if ($^O eq 'linux') {
	diag("grep -r Mem /proc/meminfo");
	diag(`grep -r Mem /proc/meminfo`);
	diag("ulimit -a | grep -i mem");
	diag(`ulimit -a | grep -i mem`);
} elsif ($^O =~ /bsd/i) {
	diag("sysctl hw | egrep 'hw.(phys|user|real)'");
	diag(`sysctl hw | egrep 'hw.(phys|user|real)'`);
	diag("ulimit -a | grep -i mem");
	diag(`ulimit -a | grep -i mem`);
}
my $count = 0;
foreach my $name (Firefox::Marionette::Profile->names()) {
	my $profile = Firefox::Marionette::Profile->existing($name);
	$count += 1;
}
ok(1, "Read $count existing profiles");
diag("This firefox installation has $count existing profiles");
my $profile;
eval {
	$profile = Firefox::Marionette::Profile->existing();
};
ok(1, "Read existing profile if any");
my $firefox;
eval {
	$firefox = Firefox::Marionette->new(firefox_binary => '/firefox/is/not/here');
};
chomp $@;
ok((($@) and (not($firefox))), "Firefox::Marionette->new() threw an exception when launched with an incorrect path to a binary:$@");
eval {
	$firefox = Firefox::Marionette->new(firefox => $^X);
};
chomp $@;
ok((($@) and (not($firefox))), "Firefox::Marionette->new() threw an exception when launched with a path to a non firefox binary:$@");
my $tls_tests_ok;
if ( 
	!IO::Socket::SSL->new(
	PeerAddr => 'missing.example.org:443',
	SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
		) &&
	IO::Socket::SSL->new(
	PeerAddr => 'untrusted-root.badssl.com:443',
	SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
		) &&
	!IO::Socket::SSL->new(
	PeerAddr => 'untrusted-root.badssl.com:443',
	SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
		) &&
	IO::Socket::SSL->new(
	PeerAddr => 'metacpan.org:443',
	SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
		)) {
	diag("TLS/Network seem okay");
	$tls_tests_ok = 1;
} else {
	diag("TLS/Network are NOT okay");
}
my $skip_message;
ok($profile = Firefox::Marionette::Profile->new(), "Firefox::Marionette::Profile->new() correctly returns a new profile");
ok(((defined $profile->get_value('marionette.port')) && ($profile->get_value('marionette.port') == 0)), "\$profile->get_value('marionette.port') correctly returns 0");
ok($profile->set_value('browser.link.open_newwindow', 2), "\$profile->set_value('browser.link.open_newwindow', 2) to force new windows to appear");
ok($profile->set_value('browser.link.open_external', 2), "\$profile->set_value('browser.link.open_external', 2) to force new windows to appear");
ok($profile->set_value('browser.block.target_new_window', 'false'), "\$profile->set_value('browser.block.target_new_window', 'false') to force new windows to appear");
$profile->set_value('browser.link.open_newwindow', 2); # open in a new window
$profile->set_value('browser.link.open_newwindow.restriction', 1); # don't restrict new windows
$profile->set_value('dom.disable_open_during_load', 'false'); # don't block popups during page load
$profile->set_value('privacy.popups.disable_from_plugin', 0); # no restrictions
$profile->set_value('security.OCSP.GET.enabled', 'false'); 
$profile->clear_value('security.OCSP.enabled');  # just testing
$profile->set_value('security.OCSP.enabled', 0); 
my $correct_exit_status = 0;
my $mozilla_pid_support;
SKIP: {
	($skip_message, $firefox) = start_firefox(0, debug => 1, profile => $profile, mime_types => [ 'application/pkcs10', 'application/pdf' ]);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 38);
	}
	ok($firefox, "Firefox has started in Marionette mode");
	ok((scalar grep { /^application\/pkcs10$/ } $firefox->mime_types()), "application/pkcs10 has been added to mime_types");
	ok((scalar grep { /^application\/pdf$/ } $firefox->mime_types()), "application/pdf was already in mime_types");
	ok((scalar grep { /^application\/x\-gzip$/ } $firefox->mime_types()), "application/x-gzip was already in mime_types");
	ok((!scalar grep { /^text\/html$/ } $firefox->mime_types()), "text/html should not be in mime_types");
	my $capabilities = $firefox->capabilities();
	ok(1, "\$capabilities->proxy() " . defined $capabilities->proxy() ? "shows an existing proxy setup" : "is undefined");
	diag("Browser version is " . $capabilities->browser_version());
	if ($firefox->nightly()) {
		diag($capabilities->browser_version() . " is a nightly release");
	}
	if ($firefox->developer()) {
		diag($capabilities->browser_version() . " is a developer release");
	}
	($major_version, $minor_version, $patch_version) = split /[.]/smx, $capabilities->browser_version();
	if (!defined $minor_version) {
		$minor_version = '';
	}
	if (!defined $patch_version) {
		$patch_version = '';
	}
	diag("Operating System is " . ($capabilities->platform_name() || 'Unknown') . q[ ] . ($capabilities->platform_version() || 'Unknown'));
	diag("Profile Directory is " . $capabilities->moz_profile());
	diag("Mozilla PID is " . ($capabilities->moz_process_id() || 'Unknown'));
	$mozilla_pid_support = defined $capabilities->moz_process_id() ? 1 : 0;
	diag("Firefox BuildID is " . ($capabilities->moz_build_id() || 'Unknown'));
	diag("Addons are " . ($firefox->addons() ? 'working' : 'disabled'));
	ok($firefox->application_type(), "\$firefox->application_type() returns " . $firefox->application_type());
	ok($firefox->marionette_protocol() =~ /^\d+$/smx, "\$firefox->marionette_protocol() returns " . $firefox->marionette_protocol());
	my $window_type = $firefox->window_type();
	ok($window_type && $window_type eq 'navigator:browser', "\$firefox->window_type() returns 'navigator:browser':$window_type");
	ok($firefox->sleep_time_in_ms() == 1, "\$firefox->sleep_time_in_ms() is 1 millisecond");
	my $new_x = 3;
	my $new_y = 9;
	my $new_height = 452;
	my $new_width = 326;
	my $new = Firefox::Marionette::Window::Rect->new( pos_x => $new_x, pos_y => $new_y, height => $new_height, width => $new_width );
	my $old;
	eval {
		$old = $firefox->window_rect($new);
	};
	SKIP: {
		if (($major_version < 50) && (!defined $old)) {
			skip("Firefox $major_version does not appear to support the \$firefox->window_rect() method", 13);
		}
		TODO: {
			local $TODO = $major_version < 55 ? $capabilities->browser_version() . " probably does not have support for \$firefox->window_rect()->pos_x()" : q[];
			ok(defined $old->pos_x() && $old->pos_x() =~ /^\-?\d+([.]\d+)?$/, "Window used to have a X position of " . (defined $old->pos_x() ? $old->pos_x() : q[]));
			ok(defined $old->pos_y() && $old->pos_y() =~ /^\-?\d+([.]\d+)?$/, "Window used to have a Y position of " . (defined $old->pos_y() ? $old->pos_y() : q[]));
		}
		ok($old->width() =~ /^\d+([.]\d+)?$/, "Window used to have a width of " . $old->width());
		ok($old->height() =~ /^\d+([.]\d+)?$/, "Window used to have a height of " . $old->height());
		my $new2 = $firefox->window_rect();
		TODO: {
			local $TODO = $major_version < 55 ? $capabilities->browser_version() . " probably does not have support for \$firefox->window_rect()->pos_x()" : q[];
			ok(defined $new2->pos_x() && $new2->pos_x() == $new->pos_x(), "Window has a X position of " . $new->pos_x());
			ok(defined $new2->pos_y() && $new2->pos_y() == $new->pos_y(), "Window has a Y position of " . $new->pos_y());
		}
		TODO: {
			local $TODO = $major_version >= 60 && $^O eq 'darwin' ? "darwin has dodgy support for \$firefox->window_rect()->width()" : $firefox->nightly() ? "Nightly returns incorrect values for \$firefox->window_rect()->width()" : q[];
			ok($new2->width() >= $new->width(), "Window has a width of " . $new->width() . ":" . $new2->width());
		}
		ok($new2->height() == $new->height(), "Window has a height of " . $new->height());
		TODO: {
			local $TODO = $major_version < 57 ? $capabilities->browser_version() . " probably does not have support for \$firefox->window_rect()->wstate()" : $major_version >= 66 ? $capabilities->browser_version() . " probably does not have support for \$firefox->window_rect()->wstate()" : q[];
			ok(defined $old->wstate() && $old->wstate() =~ /^\w+$/, "Window has a state of " . ($old->wstate() || q[]));
		}
		my $rect = $firefox->window_rect();
		TODO: {
			local $TODO = $major_version < 55 ? $capabilities->browser_version() . " probably does not have support for \$firefox->window_rect()->pos_x()" : q[];
			ok(defined $rect->pos_x() && $rect->pos_x() =~ /^[-]?\d+([.]\d+)?$/, "Window has a X position of " . ($rect->pos_x() || q[]));
			ok(defined $rect->pos_y() && $rect->pos_y() =~ /^[-]?\d+([.]\d+)?$/, "Window has a Y position of " . ($rect->pos_y() || q[]));
		}
		ok($rect->width() =~ /^\d+([.]\d+)?$/, "Window has a width of " . $rect->width());
		ok($rect->height() =~ /^\d+([.]\d+)?$/, "Window has a height of " . $rect->height());
	}
	my $page_timeout = 45_043;
	my $script_timeout = 48_021;
	my $implicit_timeout = 41_001;
	$new = Firefox::Marionette::Timeouts->new(page_load => $page_timeout, script => $script_timeout, implicit => $implicit_timeout);
	my $timeouts = $firefox->timeouts($new);
	ok((ref $timeouts) eq 'Firefox::Marionette::Timeouts', "\$firefox->timeouts() returns a Firefox::Marionette::Timeouts object");
	ok($timeouts->page_load() == 300_000, "\$timeouts->page_load() is 5 minutes");
	ok($timeouts->script() == 30_000, "\$timeouts->script() is 30 seconds");
	ok(defined $timeouts->implicit() && $timeouts->implicit() == 0, "\$timeouts->implicit() is 0 milliseconds");
	$timeouts = $firefox->timeouts($new);
	ok($timeouts->page_load() == $page_timeout, "\$timeouts->page_load() is $page_timeout");
	ok($timeouts->script() == $script_timeout, "\$timeouts->script() is $script_timeout");
	ok($timeouts->implicit() == $implicit_timeout, "\$timeouts->implicit() is $implicit_timeout");
	ok(!defined $firefox->child_error(), "Firefox does not have a value for child_error");
	ok($firefox->alive(), "Firefox is still alive");
	ok(not($firefox->script('window.open("https://duckduckgo.com", "_blank");')), "Opening new window to duckduckgo.com via 'window.open' script");
	ok($firefox->close_current_window_handle(), "Closed new tab/window");
	SKIP: {
		if ($major_version < 55) {
			skip("Deleting and re-creating sessions can hang firefox for old versions", 1);
		}
		ok($firefox->delete_session()->new_session(), "\$firefox->delete_session()->new_session() has cleared the old session and created a new session");
	}
	my $child_error = $firefox->quit();
	if ($child_error != 0) {
		diag("Firefox exited with a \$? of $child_error");
	}
	ok($child_error =~ /^\d+$/, "Firefox has closed with an integer exit status of " . $child_error);
	if ($major_version < 50) {
		$correct_exit_status = $child_error;
	}
	ok($firefox->child_error() == $child_error, "Firefox returns $child_error for the child error, matching the return value of quit():$child_error:" . $firefox->child_error());
	ok(!$firefox->alive(), "Firefox is not still alive");
}
if ((!defined $major_version) || ($major_version < 40)) {
	$profile->set_value('security.tls.version.max', 3); 
}
$profile->set_value('browser.newtabpage.activity-stream.feeds.favicon', 'true'); 
$profile->set_value('browser.shell.shortcutFavicons', 'true'); 
$profile->set_value('browser.newtabpage.enabled', 'true'); 
$profile->set_value('browser.pagethumbnails.capturing_disabled', 'false', 0); 
$profile->set_value('startup.homepage_welcome_url', 'false', 0); 

SKIP: {
	if (($^O eq 'MSWin32') || ($^O eq 'cygwin')) {
		skip("$^O is not supported for reconnecting yet", 8);
	} elsif (!$mozilla_pid_support) {
		skip("No pid support for this version of firefox", 8);
	} elsif (!$ENV{RELEASE_TESTING}) {
		skip("No survive testing except for RELEASE_TESTING", 8);
	}
	($skip_message, $firefox) = start_firefox(0, debug => 1, survive => 1);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 8);
	}
	ok($firefox, "Firefox has started in Marionette mode with as survivable");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	my $firefox_pid = $capabilities->moz_process_id();
	ok($firefox_pid, "Firefox process has a process id of $firefox_pid");
	if (!$ENV{FIREFOX_HOST}) {
		ok((kill 0, $firefox_pid), "Can contact firefox process ($firefox_pid)");
	}
	$firefox = undef;
	if (!$ENV{FIREFOX_HOST}) {
		ok((kill 0, $firefox_pid), "Can contact firefox process ($firefox_pid)");
	}
	($skip_message, $firefox) = start_firefox(0, debug => 1, reconnect => 1);
	ok($firefox, "Firefox has reconnected in Marionette mode");
	$capabilities = $firefox->capabilities();
	ok($firefox_pid == $capabilities->moz_process_id(), "Firefox has the same process id");
	$firefox = undef;
	if (!$ENV{FIREFOX_HOST}) {
		ok((!kill 0, $firefox_pid), "Cannot contact firefox process ($firefox_pid)");
	}
}

if (($^O eq 'MSWin32') || ($^O eq 'cygwin')) {
} elsif ($ENV{RELEASE_TESTING}) {
	eval {
		$ca_cert_handle = File::Temp::tempfile(File::Spec->catfile(File::Spec->tmpdir(), 'firefox_test_ca_private_XXXXXXXXXXX')) or Carp::croak("Failed to open temporary file for writing:$!");
		fcntl $ca_cert_handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
		my $ca_private_key_handle = File::Temp::tempfile(File::Spec->catfile(File::Spec->tmpdir(), 'firefox_test_ca_private_XXXXXXXXXXX')) or Carp::croak("Failed to open temporary file for writing:$!");
		fcntl $ca_private_key_handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
		system {'openssl'} 'openssl', 'genrsa', '-out' => '/dev/fd/' . fileno $ca_private_key_handle, 4096 and Carp::croak("Failed to generate a private key:$!");
		my $ca_config_handle = File::Temp::tempfile(File::Spec->catfile(File::Spec->tmpdir(), 'firefox_test_ca_config_XXXXXXXXXXX')) or Carp::croak("Failed to open temporary file for writing:$!");
		$ca_config_handle->print(<<"_CONFIG_");
[ req ]
distinguished_name     = req_distinguished_name
attributes             = req_attributes
prompt                 = no

[ req_distinguished_name ]
C                      = AU
ST                     = Victoria
L                      = Melbourne
O                      = David Dick
OU                     = CPAN
CN                     = Firefox::Marionette Root CA
emailAddress           = ddick\@cpan.org

[ req_attributes ]
_CONFIG_
		seek $ca_config_handle, 0, 0 or Carp::croak("Failed to seek to start of temporary file:$!");
		fcntl $ca_config_handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
		system {'openssl'} 'openssl', 'req', '-x509',
			'-set_serial' => '1',
			'-config'     => '/dev/fd/' . fileno $ca_config_handle,
			'-days'       => 10,
			'-key'        => '/dev/fd/' . fileno $ca_private_key_handle,
			'-out'        => '/dev/fd/' . fileno $ca_cert_handle
			and Carp::croak("Failed to generate a CA root certificate:$!");
		1;
	} or do {
		chomp $@;
		diag("Did not generate a CA root certificate:$@");
	};
}

SKIP: {
	my $daemon = HTTP::Daemon->new(LocalAddr => 'localhost') || die "Failed to create HTTP::Daemon";
	my $localPort = URI->new($daemon->url())->port();
	my $proxy = Firefox::Marionette::Proxy->new( http => 'localhost:' . $localPort, https => 'proxy.example.org:4343', ftp => 'ftp.example.org:2121', none => [ 'local.example.org' ], socks => 'socks.example.org:1081' );
	($skip_message, $firefox) = start_firefox(0, debug => 1, sleep_time_in_ms => 5, profile => $profile, capabilities => Firefox::Marionette::Capabilities->new(proxy => $proxy, moz_headless => 1, strict_file_interactability => 1, accept_insecure_certs => 1, page_load_strategy => 'eager', unhandled_prompt_behavior => 'accept and notify', moz_webdriver_click => 1, moz_accessibility_checks => 1, moz_use_non_spec_compliant_pointer_origin => 1, timeouts => Firefox::Marionette::Timeouts->new(page_load => 54_321, script => 4567, implicit => 6543)));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 26);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	ok($firefox->sleep_time_in_ms() == 5, "\$firefox->sleep_time_in_ms() is 5 milliseconds");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!grep /^set_window_rect$/, $capabilities->enumerate()) {
			diag("\$capabilities->set_window_rect is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->set_window_rect is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->set_window_rect() =~ /^[10]$/smx, "\$capabilities->set_window_rect() is a 0 or 1");
	}
	SKIP: {
		if (!grep /^unhandled_prompt_behavior$/, $capabilities->enumerate()) {
			diag("\$capabilities->unhandled_prompt_behavior is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->unhandled_prompt_behavior is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->unhandled_prompt_behavior() eq 'accept and notify', "\$capabilities->unhandled_prompt_behavior() is 'accept and notify'");
	}
	SKIP: {
		if (!grep /^moz_shutdown_timeout$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_shutdown_timeout is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_shutdown_timeout is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_shutdown_timeout() =~ /^\d+$/smx, "\$capabilities->moz_shutdown_timeout() is an integer");
	}
	SKIP: {
		if (!grep /^strict_file_interactability$/, $capabilities->enumerate()) {
			diag("\$capabilities->strict_file_interactability is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->strict_file_interactability is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->strict_file_interactability() == 1, "\$capabilities->strict_file_interactability() is set to true");
	}
	SKIP: {
		if (!grep /^page_load_strategy$/, $capabilities->enumerate()) {
			diag("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->page_load_strategy() eq 'eager', "\$capabilities->page_load_strategy() is 'eager'");
	}
	SKIP: {
		if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
			diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->accept_insecure_certs() == 1, "\$capabilities->accept_insecure_certs() is set to true");
	}
	SKIP: {
		if (!grep /^moz_webdriver_click$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_webdriver_click is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_webdriver_click is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_webdriver_click() == 1, "\$capabilities->moz_webdriver_click() is set to true");
	}
	SKIP: {
		if (!grep /^moz_use_non_spec_compliant_pointer_origin$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_use_non_spec_compliant_pointer_origin is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_use_non_spec_compliant_pointer_origin is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_use_non_spec_compliant_pointer_origin() == 1, "\$capabilities->moz_use_non_spec_compliant_pointer_origin() is set to true");
	}
	SKIP: {
		if (!grep /^moz_accessibility_checks$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_accessibility_checks is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_accessibility_checks is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_accessibility_checks() == 1, "\$capabilities->moz_accessibility_checks() is set to true");
	}
	TODO: {
		local $TODO = $major_version < 56 ? $capabilities->browser_version() . " does not have support for -headless argument" : q[];
		ok($capabilities->moz_headless() == 1 || $ENV{FIREFOX_VISIBLE} || 0, "\$capabilities->moz_headless() is set to " . ($ENV{FIREFOX_VISIBLE} ? 'true' : 'false'));
	}
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 13);
	}
	$capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 10);
		}
		ok($capabilities->proxy()->type() eq 'manual', "\$capabilities->proxy()->type() is 'manual'");
		ok($capabilities->proxy()->http() eq 'localhost:' . $localPort, "\$capabilities->proxy()->http() is 'localhost:" . $localPort . "':" . $capabilities->proxy()->http());
		ok($capabilities->proxy()->https() eq 'proxy.example.org:4343', "\$capabilities->proxy()->https() is 'proxy.example.org:4343'");
		ok($capabilities->proxy()->ftp() eq 'ftp.example.org:2121', "\$capabilities->proxy()->ftp() is 'ftp.example.org:2121'");
		ok($capabilities->timeouts()->page_load() == 54_321, "\$capabilities->timeouts()->page_load() is '54,321'");
		ok($capabilities->timeouts()->script() == 4567, "\$capabilities->timeouts()->script() is '4,567'");
		ok($capabilities->timeouts()->implicit() == 6543, "\$capabilities->timeouts()->implicit() is '6,543'");
		my $none = 0;
		foreach my $host ($capabilities->proxy()->none()) {
			$none += 1;
		}
		ok($capabilities->proxy()->socks() eq 'socks.example.org:1081', "\$capabilities->proxy()->socks() is 'socks.example.org:1081':" . $capabilities->proxy()->socks() );
		ok($capabilities->proxy()->socks_version() == 5, "\$capabilities->proxy()->socks_version() is 5");
		TODO: {
			local $TODO = $major_version < 58 ? $capabilities->browser_version() . " does not have support for \$firefox->capabilities()->none()" : q[];
			ok($none == 1, "\$capabilities->proxy()->none() is a reference to a list with 1 element");
		}
	}
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 2);
	}
	SKIP: {
		if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
			diag("\$capabilities->proxy is not supported for remote hosts");
			skip("\$capabilities->proxy is not supported for remote hosts", 1);
		} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
			diag("\$capabilities->proxy is not supported for remote hosts");
			skip("\$capabilities->proxy is not supported for remote hosts", 3);
		} elsif (!$capabilities->proxy()) {
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 1);
		} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
			if ($ENV{RELEASE_TESTING}) {
				if (my $pid = fork) {
					$firefox->go('http://wtf.example.org');
					ok($firefox->html() =~ /success/smx, "Correctly accessed the Proxy");
					diag($firefox->html());
					while(kill $signals_by_name{TERM}, $pid) {
						waitpid $pid, POSIX::WNOHANG();
						sleep 1;
					}
				} elsif (defined $pid) {
					eval {
						local $SIG{ALRM} = sub { die "alarm during proxy server\n" };
						alarm 5;
						$0 = "[Test HTTP Proxy for " . getppid . "]";
						while (my $connection = $daemon->accept()) {
							diag("Accepted connection");
							if (my $child = fork) {
							} elsif (defined $child) {
								eval {
									local $SIG{ALRM} = sub { die "alarm during proxy server accept\n" };
									alarm 5;
									while (my $request = $connection->get_request()) {
										diag("Got request for " . $request->uri());
										my $response = HTTP::Response->new(200, "OK", undef, "success");
										$connection->send_response($response);
									}
									$connection->close;
									$connection = undef;
									exit 0;
								} or do {
									chomp $@;
									diag("Caught exception in proxy server accept:$@");
								};
								exit 1;
							} else {
								diag("Failed to fork connection:$!");
								die "Failed to fork:$!";
							}
						}
					} or do {
						chomp $@;
						diag("Caught exception in proxy server:$@");
					};
					exit 1;
				} else {
					diag("Failed to fork http proxy:$!");
					die "Failed to fork:$!";
				}
			} else {
				skip("Skipping proxy forks except for RELEASE_TESTING=1", 1);
				diag("Skipping proxy forks except for RELEASE_TESTING=1");
			}
		} else {
			skip("No forking available for $^O", 1);
			diag("No forking available for $^O");
		}
	}
	ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
}

SKIP: {
	($skip_message, $firefox) = start_firefox(0, chatty => 1, debug => 1, page_load => 65432, capabilities => Firefox::Marionette::Capabilities->new(proxy => Firefox::Marionette::Proxy->new( pac => URI->new('https://proxy.example.org')), moz_headless => 1));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 6);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 2);
		}
		ok($capabilities->proxy()->type() eq 'pac', "\$capabilities->proxy()->type() is 'pac'");
		ok($capabilities->proxy()->pac()->host() eq 'proxy.example.org', "\$capabilities->proxy()->pac()->host() is 'proxy.example.org'");
	}
	ok($capabilities->timeouts()->page_load() == 65432, "\$firefox->capabilities()->timeouts()->page_load() correctly reflects the page_load shortcut timeout");
	ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
}

SKIP: {
	($skip_message, $firefox) = start_firefox(1, seer => 1, chatty => 1, debug => 1, capabilities => Firefox::Marionette::Capabilities->new(proxy => Firefox::Marionette::Proxy->new( host => 'proxy.example.org:3128')));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 7);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'manual', "\$capabilities->proxy()->type() is 'manual'");
		ok($capabilities->proxy()->https() eq 'proxy.example.org:3128', "\$capabilities->proxy()->https() is 'proxy.example.org:3128'");
		ok($capabilities->proxy()->http() eq 'proxy.example.org:3128', "\$capabilities->proxy()->http() is 'proxy.example.org:3128'");
		ok($capabilities->proxy()->ftp() eq 'proxy.example.org:3128', "\$capabilities->proxy()->ftp() is 'proxy.example.org:3128'");
	}
	ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
}

SKIP: {
	($skip_message, $firefox) = start_firefox(0, capabilities => Firefox::Marionette::Capabilities->new(accept_insecure_certs => 1, moz_headless => 1));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 6);
	}
	if (!$tls_tests_ok) {
		skip("TLS test infrastructure seems compromised", 6);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
		diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
		skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 4);
	}
	ok($capabilities->accept_insecure_certs(), "\$capabilities->accept_insecure_certs() is true");
	ok($firefox->go(URI->new("https://untrusted-root.badssl.com/")), "https://untrusted-root.badssl.com/ has been loaded");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 2);
	}
	my $raw_pdf;
	eval {
		my $handle = $firefox->pdf();
		ok(ref $handle eq 'File::Temp', "\$firefox->pdf() returns a File::Temp object:" . ref $handle);
		my $result;
		while($result = $handle->read(my $buffer, 4096)) {
			$raw_pdf .= $buffer;
		}
		defined $result or die "Failed to read from File::Temp handle:$!";
		close $handle or die "Failed to close File::Temp handle:$!";
		diag("WebDriver:Print command is supported for " . $capabilities->browser_version());
		1;
	} or do {
		chomp $@;
		diag("WebDriver:Print command is not supported for " . $capabilities->browser_version() . ":$@");
		skip("WebDriver:Print command is not supported for " . $capabilities->browser_version() . ":$@", 2);
	};
	ok($raw_pdf =~ /^%PDF\-\d+[.]\d+/smx, "PDF is produced in file handle for pdf method");
	eval { require PDF::API2; } or do {
		diag("PDF::API2 is not available");
		skip("PDF::API2 is not available", 2);
	};
	diag("PDF::API2 tests are being run");
	my $pdf = PDF::API2->open_scalar($raw_pdf);
	my $pages = $pdf->pages();
	my $page = $pdf->openpage(0);
	my ($llx, $lly, $urx, $ury) = $page->mediabox();
	ok($urx == 612 && $ury == 792, "Correct page height ($ury) and width ($urx)");
	if ($ENV{RELEASE_TESTING}) {
		$raw_pdf = $firefox->pdf(raw => 1, printBackground => 1, landscape => 0, page => { width => 7, height => 12 });
		$pdf = PDF::API2->open_scalar($raw_pdf);
		$page = $pdf->openpage(0);
		($llx, $lly, $urx, $ury) = $page->mediabox();
		$urx = int $urx; # for darwin
		$ury = int $ury; # for darwin
		ok(((centimetres_to_points(7) == $urx) || (centimetres_to_points(7) == $urx - 1)) &&
			 ((centimetres_to_points(12) == $ury) || (centimetres_to_points(12) == $ury - 1)),
				"Correct page height of " . centimetres_to_points(12) . " (was actually $ury) and width " . centimetres_to_points(7) . " (was actually $urx)");
		$raw_pdf = $firefox->pdf(raw => 1, shrinkToFit => 1, landscape => 1, page => { width => 7, height => 12 });
		$pdf = PDF::API2->open_scalar($raw_pdf);
		$page = $pdf->openpage(0);
		($llx, $lly, $urx, $ury) = $page->mediabox();
		$urx = int $urx; # for darwin
		$ury = int $ury; # for darwin
		ok(((centimetres_to_points(12) == $urx) || (centimetres_to_points(12) == $urx - 1)) &&
			 ((centimetres_to_points(7) == $ury) || (centimetres_to_points(7) == $ury - 1)),
				"Correct page height of " . centimetres_to_points(7) . " (was actually $ury) and width " . centimetres_to_points(12) . " (was actually $urx)");
		foreach my $paper_size ($firefox->paper_sizes()) {
			$raw_pdf = $firefox->pdf(raw => 1, size => $paper_size, print_background => 1, shrink_to_fit => 1);
			$pdf = PDF::API2->open_scalar($raw_pdf);
			$page = $pdf->openpage(0);
			($llx, $lly, $urx, $ury) = $page->mediabox();
			ok($raw_pdf =~ /^%PDF\-\d+[.]\d+/smx, "Raw PDF is produced for pdf method with size of $paper_size (width $urx points, height $ury points)");
		}
		my %paper_sizes = (
						'A4' => { width => 21, height => 29.7 },
						'leTter' => { width => 21.6, height => 27.9 },
					);
		foreach my $paper_size (sort { $a cmp $b } keys %paper_sizes) {
			$raw_pdf = $firefox->pdf(raw => 1, size => $paper_size, margin => { top => 2, left => 2, right => 2, bottom => 2 });
			ok($raw_pdf =~ /^%PDF\-\d+[.]\d+/smx, "Raw PDF is produced for pdf method");
			$pdf = PDF::API2->open_scalar($raw_pdf);
			$pages = $pdf->pages();
			$page = $pdf->openpage(0);
			($llx, $lly, $urx, $ury) = $page->mediabox();
			$urx = int $urx; # for darwin
			$ury = int $ury; # for darwin
			ok(((centimetres_to_points($paper_sizes{$paper_size}->{height}) == $ury) || (centimetres_to_points($paper_sizes{$paper_size}->{height}) + 1) == $ury) &&
			   ((centimetres_to_points($paper_sizes{$paper_size}->{width}) == $urx) || (centimetres_to_points($paper_sizes{$paper_size}->{width}) + 1) == $urx), "Correct page height ($ury) and width ($urx) for " . uc $paper_size);
		}
		my $result;
		eval { $firefox->pdf(size => 'UM'); $result = 1; } or do {
			$result = 0;
			chomp $@;
		};
		ok($result == 0, "Correctly throws exception for unknown PDF page size:$@");
		$result = undef;
		eval { $firefox->pdf(margin => { foo => 21 }); $result = 1; } or do {
			$result = 0;
			chomp $@;
		};
		ok($result == 0, "Correctly throws exception for unknown margin key:$@");
		$result = undef;
		eval { $firefox->pdf(page => { bar => 21 }); $result = 1; } or do {
			$result = 0;
			chomp $@;
		};
		ok($result == 0, "Correctly throws exception for unknown page key:$@");
		$result = undef;
		eval { $firefox->pdf(foo => 'bar'); $result = 1; } or do {
			$result = 0;
			chomp $@;
		};
		ok($result == 0, "Correctly throws exception for unknown pdf key:$@");
	}
}

sub centimetres_to_points {
	my ($centimetres) = @_;
	my $inches = $centimetres / 2.54;
	my $points = int $inches * 72;
	return $points;
}

SKIP: {
	($skip_message, $firefox) = start_firefox(0, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 1));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 4);
	}
	if (!$tls_tests_ok) {
		skip("TLS test infrastructure seems compromised", 4);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
		diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
		skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 2);
	}
	ok(!$capabilities->accept_insecure_certs(), "\$capabilities->accept_insecure_certs() is false");
	eval { $firefox->go(URI->new("https://untrusted-root.badssl.com/")) };
	my $exception = "$@";
	chomp $exception;
	ok(ref $@ eq 'Firefox::Marionette::Exception::InsecureCertificate', "https://untrusted-root.badssl.com/ threw an exception:$exception");
}

SKIP: {
	($skip_message, $firefox) = start_firefox(0, har => 1, debug => 1, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 1));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 6);
	}
	if (!$tls_tests_ok) {
		skip("TLS test infrastructure seems compromised", 6);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
        my $testing_header_name = 'X-CPAN-Testing';
        my $testing_header_value = (ref $firefox) . q[ All ] . $Firefox::Marionette::VERSION;
        $firefox->add_header($testing_header_name => $testing_header_value);
        my $testing_header_2_name = 'X-CPAN-Testing2';
        my $testing_header_2_value = (ref $firefox) . q[ All2 ] . $Firefox::Marionette::VERSION;
        $firefox->delete_header($testing_header_2_name)->add_header($testing_header_2_name => $testing_header_2_value);
        my $testing_site_header_name = 'X-CPAN-Site-Testing';
        my $testing_site_header_value = (ref $firefox) . q[ Site ] . $Firefox::Marionette::VERSION;
	my $site_hostname = 'fastapi.metacpan.org';
        $firefox->add_site_header($site_hostname, $testing_site_header_name => $testing_site_header_value);
        my $testing_site_header_2_name = 'X-CPAN-Site-Testing2';
        my $testing_site_header_2_value = (ref $firefox) . q[ Site2 ] . $Firefox::Marionette::VERSION;
        $firefox->delete_site_header($site_hostname, $testing_site_header_2_name)->add_site_header($site_hostname, $testing_site_header_2_name => $testing_site_header_2_value);
        my $testing_no_site_header_name = 'X-CPAN-No-Site-Testing';
        my $testing_no_site_header_value = (ref $firefox) . q[ None ] . $Firefox::Marionette::VERSION;
	my $no_site_hostname = 'missing.metacpan.org';
        $firefox->add_site_header($no_site_hostname, $testing_no_site_header_name => $testing_no_site_header_value);
        $firefox->delete_header('Accept-Language');
        $firefox->delete_site_header('fastapi.metacpan.org', 'Cache-Control');
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
		diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
		skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 3);
	}
	ok(!$capabilities->accept_insecure_certs(), "\$capabilities->accept_insecure_certs() is false");
	if ($ENV{RELEASE_TESTING}) { # har sometimes hangs and sometimes metacpan.org fails certificate checks.  for example. http://www.cpantesters.org/cpan/report/e71bfb3b-7413-1014-98e6-045206f7812f
		ok($firefox->go(URI->new("https://fastapi.metacpan.org/author/DDICK")), "https://fastapi.metacpan.org/author/DDICK has been loaded");
		ok($firefox->interactive() && $firefox->loaded(), "\$firefox->interactive() and \$firefox->loaded() are ok");
		if ($major_version < 61) {
			skip("HAR support not available in Firefox before version 61", 1);
		}
		my $correct = 0;
		my $number_of_entries = 0;
		while($number_of_entries == 0) {
			my $har = $firefox->har();
			ok($har->{log}->{creator}->{name} eq ucfirst $firefox->capabilities()->browser_name(), "\$firefox->har() gives a data structure with the correct creator name");
			$number_of_entries = 0;
			$correct = 0;
			foreach my $entry (@{$har->{log}->{entries}}) {
				$number_of_entries += 1;
			}
			if ($number_of_entries > 0) {
				foreach my $header (@{$har->{log}->{entries}->[0]->{request}->{headers}} ) {
					if (lc $header->{name} eq $testing_no_site_header_name) {
						diag("Should not have found an '$header->{name}' header");
						$correct = -1;
					} elsif (lc $header->{name} eq 'accept-language') {
						diag("Should not have found an '$header->{name}' header");
						$correct = -1;
					} elsif (lc $header->{name} eq 'cache-control') {
						diag("Should not have found an '$header->{name}' header");
						$correct = -1;
					} elsif ((lc $header->{name} eq lc $testing_header_name) && ($header->{value} eq $testing_header_value)) {
						diag("Found an '$header->{name}' header");
						if ($correct >= 0) {
							$correct += 1;
						}
					} elsif ((lc $header->{name} eq lc $testing_header_2_name) && ($header->{value} eq $testing_header_2_value)) {
						diag("Found an '$header->{name}' header");
						if ($correct >= 0) {
							$correct += 1;
						}
					} elsif ((lc $header->{name} eq lc $testing_site_header_name) && ($header->{value} eq $testing_site_header_value)) {
						diag("Found an '$header->{name}' header");
						if ($correct >= 0) {
							$correct += 1;
						}
					} elsif ((lc $header->{name} eq lc $testing_site_header_2_name) && ($header->{value} eq $testing_site_header_2_value)) {
						diag("Found an '$header->{name}' header");
						if ($correct >= 0) {
							$correct += 1;
						}
					}
				}
			}
		}
		ok($correct == 4, "Correct headers have been set");
	}
}

SKIP: {
	($skip_message, $firefox) = start_firefox(0, debug => 0, page_load => 600000, script => 5432, profile => $profile, capabilities => Firefox::Marionette::Capabilities->new(accept_insecure_certs => 1, page_load_strategy => 'eager'));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 247);
	}
	ok($firefox, "Firefox has started in Marionette mode without defined capabilities, but with a defined profile and debug turned off");
	my $frame_url = 'https://www.w3schools.com/html/tryit.asp?filename=tryhtml_iframe_height_width';
	my $frame_element = '//iframe[@name="iframeResult"]';
	ok($firefox->go(URI->new($frame_url)), "$frame_url has been loaded");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 246);
	}
	ok($firefox->window_handle() =~ /^\d+$/, "\$firefox->window_handle() is an integer:" . $firefox->window_handle());
	my $chrome_window_handle_supported;
	eval {
		$chrome_window_handle_supported = $firefox->chrome_window_handle();
	} or do {
		diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version:$@");
	};
	SKIP: {
		if (!$chrome_window_handle_supported) {
			diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		ok($chrome_window_handle_supported =~ /^\d+$/, "\$firefox->chrome_window_handle() is an integer:" . $firefox->chrome_window_handle());
	}
        ok($firefox->capabilities()->timeouts()->script() == 5432, "\$firefox->capabilities()->timeouts()->script() correctly reflects the scripts shortcut timeout:" . $firefox->capabilities()->timeouts()->script());
	SKIP: {
		if (!$chrome_window_handle_supported) {
			diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 2);
		}
		ok($firefox->chrome_window_handle() == $firefox->current_chrome_window_handle(), "\$firefox->chrome_window_handle() is equal to \$firefox->current_chrome_window_handle()");
		ok(scalar $firefox->chrome_window_handles() == 1, "There is one window/tab open at the moment");
	}
	ok(scalar $firefox->window_handles() == 1, "There is one actual window open at the moment");
	my $original_chrome_window_handle;
	SKIP: {
		if (!$chrome_window_handle_supported) {
			diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		($original_chrome_window_handle) = $firefox->chrome_window_handles();
		foreach my $handle ($firefox->chrome_window_handles()) {
			ok($handle =~ /^\d+$/, "\$firefox->chrome_window_handles() returns a list of integers:" . $handle);
		}
	}
	my ($original_window_handle) = $firefox->window_handles();
	foreach my $handle ($firefox->window_handles()) {
		ok($handle =~ /^\d+$/, "\$firefox->window_handles() returns a list of integers:" . $handle);
	}
	ok(not($firefox->script('window.open("https://duckduckgo.com", "_blank");')), "Opening new window to duckduckgo.com via 'window.open' script");
	ok(scalar $firefox->window_handles() == 2, "There are two actual windows open at the moment");
	my $new_chrome_window_handle;
	SKIP: {
		if (!$chrome_window_handle_supported) {
			diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 4);
		}
		ok(scalar $firefox->chrome_window_handles() == 2, "There are two windows/tabs open at the moment");
		foreach my $handle ($firefox->chrome_window_handles()) {
			ok($handle =~ /^\d+$/, "\$firefox->chrome_window_handles() returns a list of integers:" . $handle);
			if ($handle != $original_chrome_window_handle) {
				$new_chrome_window_handle = $handle;
			}
		}
		ok($new_chrome_window_handle, "New chrome window handle $new_chrome_window_handle detected");
	}
	my $new_window_handle;
	foreach my $handle ($firefox->window_handles()) {
		ok($handle =~ /^\d+$/, "\$firefox->window_handles() returns a list of integers:" . $handle);
		if ($handle != $original_window_handle) {
			$new_window_handle = $handle;
		}
	}
	ok($new_window_handle, "New window handle $new_window_handle detected");
	TODO: {
		my $screen_orientation = q[];
		eval {
			$screen_orientation = $firefox->screen_orientation();
			ok($screen_orientation, "\$firefox->screen_orientation() is " . $screen_orientation);
		} or do {
			if (($@->isa('Firefox::Marionette::Exception')) && ($@ =~ /(?:Only supported in Fennec|unsupported operation: Only supported on Android).* in .* at line \d+/)) {
				local $TODO = "Only supported in Fennec";
				ok($screen_orientation, "\$firefox->screen_orientation() is " . $screen_orientation);
			} elsif ($major_version < 60) {
				my $exception = "$@";
				chomp $exception;
				diag("\$firefox->screen_orientation() is unavailable in " . $firefox->browser_version() . ":$exception");
				local $TODO = "\$firefox->screen_orientation() is unavailable in " . $firefox->browser_version() . ":$exception";
				ok($screen_orientation, "\$firefox->screen_orientation() is " . $screen_orientation);
			} else {
				ok($screen_orientation, "\$firefox->screen_orientation() is " . $screen_orientation);
			}
		};
	}
	ok($firefox->switch_to_window($original_window_handle), "\$firefox->switch_to_window() used to move back to the original window:$@");
	TODO: {
		my $element;
		eval {
			$element = $firefox->find($frame_element)->switch_to_shadow_root();
		};
		if ($@) {
			chomp $@;
			diag("Switch to shadow root is broken:$@");
		}
		local $TODO = "Switch to shadow root can be broken";
		ok($element, "Switched to $frame_element shadow root");
	}
	SKIP: {
		my $switch_to_frame;
		eval { $switch_to_frame = $firefox->list($frame_element)->switch_to_frame() };
		if ((!$switch_to_frame) && (($major_version < 50) || ($major_version > 80))) {
			chomp $@;
			diag("switch_to_frame is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("switch_to_frame is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		ok($switch_to_frame, "Switched to $frame_element frame");
	}
	SKIP: {
		my $active_frame;
		eval { $active_frame = $firefox->active_frame() };
		if ((!$active_frame) && (($major_version < 50) || ($major_version > 80))) {
			chomp $@;
			diag("\$firefox->active_frame is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("\$firefox->active_frame is not supported for $major_version.$minor_version.$patch_version:$@", 1);
		}
		ok($active_frame->isa('Firefox::Marionette::Element'), "\$firefox->active_frame() returns a Firefox::Marionette::Element object");
	}
	SKIP: {
		my $switch_to_parent_frame;
		eval {
			$switch_to_parent_frame = $firefox->switch_to_parent_frame();
		};
		if ((!$switch_to_parent_frame) && ($major_version < 50)) {
			chomp $@;
			diag("\$firefox->switch_to_parent_frame is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("\$firefox->switch_to_parent_frame is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		ok($switch_to_parent_frame, "Switched to parent frame");
	}
	SKIP: {
		if (!$chrome_window_handle_supported) {
			diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		foreach my $handle ($firefox->close_current_chrome_window_handle()) {
			local $TODO = $major_version < 52 ? "\$firefox->close_current_chrome_window_handle() can return a undef value for versions less than 52" : undef;
			ok(defined $handle && $handle == $new_chrome_window_handle, "Closed original window, which means the remaining chrome window handle should be $new_chrome_window_handle:" . ($handle || ''));
		}
	}
	ok($firefox->switch_to_window($new_window_handle), "\$firefox->switch_to_window() used to move back to the original window");
	my $metacpan_uri = 'https://metacpan.org/';
	ok($firefox->go($metacpan_uri), "$metacpan_uri has been loaded in the new window");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 224);
	}
	my $uri = $firefox->uri();
	ok($uri =~ /metacpan/smx, "\$firefox->uri() contains /metacpan/:$uri");
	if ($uri ne $metacpan_uri) {
		if (my $proxy = $firefox->capabilities()->proxy()) {
			diag("Proxy type is " . $firefox->capabilities()->proxy()->type());
			if ($firefox->capabilities()->proxy()->pac()) {
				diag("Proxy pac is " . $firefox->capabilities()->proxy()->pac());
			}
			if ($firefox->capabilities()->proxy()->https()) {
				diag("Proxy for https is " . $firefox->capabilities()->proxy()->https());
			}
			if ($firefox->capabilities()->proxy()->socks()) {
				diag("Proxy for socks is " . $firefox->capabilities()->proxy()->socks());
			}
		} else {
			diag("\$firefox->capabilities()->proxy() is not supported for " . $firefox->capabilities()->browser_version());
		}
		diag("Skipping metacpan tests as loading $metacpan_uri sent firefox to $uri");
		skip("Skipping metacpan tests as loading $metacpan_uri sent firefox to $uri", 223);
	}
	ok($firefox->title() =~ /Search/, "metacpan.org has a title containing Search");
	my $context;
	eval { $context = $firefox->context(); };
	SKIP: {
		if ((!$context) && ($major_version < 50)) {
			chomp $@;
			diag("\$firefox->context is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("\$firefox->context is not supported for $major_version.$minor_version.$patch_version", 2);
		}
		ok($firefox->context('chrome') eq 'content', "Initial context of the browser is 'content'");
		ok($firefox->context('content') eq 'chrome', "Changed context of the browser is 'chrome'");
	}
	ok($firefox->page_source() =~ /lucky/smx, "metacpan.org contains the phrase 'lucky' in page source");
	ok($firefox->html() =~ /lucky/smx, "metacpan.org contains the phrase 'lucky' in html");
	ok($firefox->refresh(), "\$firefox->refresh()");
	my $element = $firefox->active_element();
	ok($element, "\$firefox->active_element() returns an element");
	TODO: {
		local $TODO = $major_version < 50 ? "\$firefox->active_frame() is not working for $major_version.$minor_version.$patch_version" : undef;
		my $active_frame;
		eval { $active_frame = $firefox->active_frame() };
		if (($@) && ($major_version < 50)) {
			diag("\$firefox->active_frame is not supported for $major_version.$minor_version.$patch_version:$@");
		}
		ok(not(defined $active_frame), "\$firefox->active_frame() is undefined for " . $firefox->uri());
	}
	ok($firefox->find('//input[@id="search-input"]', BY_XPATH())->type('Test::More'), "Sent 'Test::More' to the 'search-input' field directly to the element");
	my $autofocus;
	ok($autofocus = $firefox->find_element('//input[@id="search-input"]')->attribute('autofocus'), "The value of the autofocus attribute is '$autofocus'");
	$autofocus = undef;
	eval {
		$autofocus = $firefox->find('//input[@id="search-input"]')->property('autofocus');
	};
	SKIP: {
		if ((!$autofocus) && ($major_version < 50)) {
			chomp $@;
			diag("The property method is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("The property method is not supported for $major_version.$minor_version.$patch_version", 4);
		}
		ok($autofocus, "The value of the autofocus property is '$autofocus'");
		ok($firefox->find_by_class('main-content')->find('//input[@id="search-input"]')->property('id') eq 'search-input', "Correctly found nested element with find");
		ok($firefox->title() eq $firefox->find_tag('title')->property('innerHTML'), "\$firefox->title() is the same as \$firefox->find_tag('title')->property('innerHTML')");
	}
	my $count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->list('//input[@id="search-input"]')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with list");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->find('//input[@id="search-input"]')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with find");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find:$count");
	$count = 0;
	foreach my $element ($firefox->has_class('main-content')->has('//input[@id="search-input"]')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with has");
		$count += 1;
	}
	$count = 0;
	foreach my $element ($firefox->has_class('main-content')->has('//input[@id="not-an-element-at-all-or-ever"]')) {
		$count += 1;
	}
	ok($count == 0, "Found no elements with nested has:$count");
	$count = 0;
	foreach my $element ($firefox->find('//input[@id="search-input"]')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found element with wantarray find");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find:$count");
	ok($firefox->find('search-input', 'id')->attribute('id') eq 'search-input', "Correctly found element when searching by id");
	ok($firefox->find('search-input', BY_ID())->attribute('id') eq 'search-input', "Correctly found element when searching by id");
	ok($firefox->has('search-input', BY_ID())->attribute('id') eq 'search-input', "Correctly found element for default has");
	ok($firefox->list_by_id('search-input')->attribute('id') eq 'search-input', "Correctly found element with list_by_id");
	ok($firefox->find_by_id('search-input')->attribute('id') eq 'search-input', "Correctly found element with find_by_id");
	ok($firefox->find_by_class('main-content')->find_by_id('search-input')->attribute('id') eq 'search-input', "Correctly found nested element with find_by_id");
	ok($firefox->find_id('search-input')->attribute('id') eq 'search-input', "Correctly found element with find_id");
	ok($firefox->has_id('search-input')->attribute('id') eq 'search-input', "Correctly found element with has_id");
	ok(!defined $firefox->has_id('search-input-totally-not-there-EVER'), "Correctly returned undef with has_id for a non existant element");
	ok($firefox->find_class('main-content')->find_id('search-input')->attribute('id') eq 'search-input', "Correctly found nested element with find_id");
	ok($firefox->has_class('main-content')->has_id('search-input')->attribute('id') eq 'search-input', "Correctly found nested element with has_id");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->list_by_id('search-input')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with list_by_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list_by_id:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->find_by_id('search-input')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with find_by_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_id:$count");
	$count = 0;
	foreach my $element ($firefox->find_class('main-content')->find_id('search-input')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with find_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_id:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_id('search-input')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found element with wantarray find_by_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_id:$count");
	ok($firefox->find('q', 'name')->attribute('id') eq 'search-input', "Correctly found element when searching by id");
	ok($firefox->find('q', BY_NAME())->attribute('id') eq 'search-input', "Correctly found element when searching by id");
	ok($firefox->list_by_name('q')->attribute('id') eq 'search-input', "Correctly found element with list_by_name");
	ok($firefox->find_by_name('q')->attribute('id') eq 'search-input', "Correctly found element with find_by_name");
	ok($firefox->find_by_class('main-content')->find_by_name('q')->attribute('id') eq 'search-input', "Correctly found nested element with find_by_name");
	ok($firefox->find_name('q')->attribute('id') eq 'search-input', "Correctly found element with find_name");
	ok($firefox->has_name('q')->attribute('id') eq 'search-input', "Correctly found element with has_name");
	ok(!defined $firefox->has_name('q-definitely-not-exists'), "Correctly returned undef for has_name and a missing element");
	ok($firefox->find_class('main-content')->find_name('q')->attribute('id') eq 'search-input', "Correctly found nested element with find_name");
	ok($firefox->has_class('main-content')->has_name('q')->attribute('id') eq 'search-input', "Correctly found nested element with has_name");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->list_by_name('q')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with list_by_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list_by_name:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->find_by_name('q')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found nested element with find_by_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_name:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_name('q')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found element with wantarray find_by_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_name:$count");
	$count = 0;
	foreach my $element ($firefox->find_name('q')) {
		ok($element->attribute('id') eq 'search-input', "Correctly found element with wantarray find_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_name:$count");
	ok($firefox->find('input', 'tag name')->attribute('id'), "Correctly found element when searching by tag name");
	ok($firefox->find('input', BY_TAG())->attribute('id'), "Correctly found element when searching by tag name");
	ok($firefox->list_by_tag('input')->attribute('id'), "Correctly found element with list_by_tag");
	ok($firefox->find_by_tag('input')->attribute('id'), "Correctly found element with find_by_tag");
	ok($firefox->find_by_class('main-content')->find_by_tag('input')->attribute('id'), "Correctly found nested element with find_by_tag");
	ok($firefox->find_tag('input')->attribute('id'), "Correctly found element with find_tag");
	ok($firefox->has_tag('input')->attribute('id'), "Correctly found element with has_tag");
	ok($firefox->find_class('main-content')->find_tag('input')->attribute('id'), "Correctly found nested element with find_tag");
	ok($firefox->has_class('main-content')->has_tag('input')->attribute('id'), "Correctly found nested element with has_tag");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->list_by_tag('input')) {
		ok($element->attribute('id'), "Correctly found nested element with list_by_tag");
		$count += 1;
	}
	ok($count == 2, "Found elements with nested list_by_tag:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->find_by_tag('input')) {
		ok($element->attribute('id'), "Correctly found nested element with find_by_tag");
		$count += 1;
	}
	ok($count == 2, "Found elements with nested find_by_tag:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_tag('input')) {
		ok($element->attribute('id'), "Correctly found element with wantarray find_by_tag");
		$count += 1;
	}
	ok($count == 2, "Found elements with wantarray find_by_tag:$count");
	$count = 0;
	foreach my $element ($firefox->find_tag('input')) {
		ok($element->attribute('id'), "Correctly found element with wantarray find_tag");
		$count += 1;
	}
	ok($count == 2, "Found elements with wantarray find_by_tag:$count");
	ok($firefox->find('form-control home-search-input', 'class name')->attribute('id'), "Correctly found element when searching by class name");
	ok($firefox->find('form-control home-search-input', BY_CLASS())->attribute('id'), "Correctly found element when searching by class name");
	ok($firefox->list_by_class('form-control home-search-input')->attribute('id'), "Correctly found element with list_by_class");
	ok($firefox->find_by_class('form-control home-search-input')->attribute('id'), "Correctly found element with find_by_class");
	ok($firefox->find_by_class('main-content')->find_by_class('form-control home-search-input')->attribute('id'), "Correctly found nested element with find_by_class");
	ok($firefox->find_class('form-control home-search-input')->attribute('id'), "Correctly found element with find_class");
	ok($firefox->find_class('main-content')->find_class('form-control home-search-input')->attribute('id'), "Correctly found nested element with find_class");
	ok($firefox->has_class('main-content')->has_class('form-control home-search-input')->attribute('id'), "Correctly found nested element with has_class");
	ok(!defined $firefox->has_class('main-content')->has_class('absolutely-can-never-exist-in-any-universe-seriously-10'), "Correctly returned undef for nested element with has_class for a missing class");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->list_by_class('form-control home-search-input')) {
		ok($element->attribute('id'), "Correctly found nested element with list_by_class");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_class:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->find_by_class('form-control home-search-input')) {
		ok($element->attribute('id'), "Correctly found element with wantarray find_by_class");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_class:$count");
	$count = 0;
	foreach my $element ($firefox->find_class('main-content')->find_class('form-control home-search-input')) {
		ok($element->attribute('id'), "Correctly found element with wantarray find_class");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_class:$count");
	ok($firefox->find('input.home-search-input', 'css selector')->attribute('id'), "Correctly found element when searching by css selector");
	ok($firefox->find('input.home-search-input', BY_SELECTOR())->attribute('id'), "Correctly found element when searching by css selector");
	ok($firefox->list_by_selector('input.home-search-input')->attribute('id'), "Correctly found element with list_by_selector");
	ok($firefox->find_by_selector('input.home-search-input')->attribute('id'), "Correctly found element with find_by_selector");
	ok($firefox->find_by_class('main-content')->find_by_selector('input.home-search-input')->attribute('id'), "Correctly found nested element with find_by_selector");
	ok($firefox->find_selector('input.home-search-input')->attribute('id'), "Correctly found element with find_selector");
	ok($firefox->find_class('main-content')->find_selector('input.home-search-input')->attribute('id'), "Correctly found nested element with find_selector");
	ok($firefox->has_class('main-content')->has_selector('input.home-search-input')->attribute('id'), "Correctly found nested element with has_selector");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->list_by_selector('input.home-search-input')) {
		ok($element->attribute('id'), "Correctly found nested element with list_by_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list_by_selector:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class('main-content')->find_by_selector('input.home-search-input')) {
		ok($element->attribute('id'), "Correctly found nested element with find_by_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_selector:$count");
	$count = 0;
	foreach my $element ($firefox->has_selector('input.home-search-input')) {
		ok($element->attribute('id'), "Correctly found wantarray element with has_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray has_selector:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_selector('input.home-search-input')) {
		ok($element->attribute('id'), "Correctly found wantarray element with find_by_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_selector:$count");
	$count = 0;
	foreach my $element ($firefox->find_selector('input.home-search-input')) {
		ok($element->attribute('id'), "Correctly found wantarray element with find_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_selector:$count");
	ok($firefox->find('API', 'link text')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element when searching by link text");
	ok($firefox->find('API', BY_LINK())->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element when searching by link text");
	ok($firefox->list_by_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with list_by_link");
	ok($firefox->find_by_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with find_by_link");
	TODO: {
		local $TODO = $major_version == 45 ? "Nested find_link can break for $major_version.$minor_version.$patch_version" : undef;
		my $result;
		eval {
			$result = $firefox->find_by_class('container-fluid')->find_by_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx;
		};
		ok($result, "Correctly found nested element with find_by_link");
	}
	ok($firefox->find_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with find_link");
	ok($firefox->has_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with has_link");
	TODO: {
		local $TODO = $major_version == 45 ? "Nested find_link can break for $major_version.$minor_version.$patch_version" : undef;
		my $result;
		eval {
			$result = $firefox->find_class('container-fluid')->find_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx;
		};
		ok($result, "Correctly found nested element with find_link");
		eval {
			$result = $firefox->has_class('container-fluid')->has_link('API')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx;
		};
		ok($result, "Correctly found nested element with has_link");
	}
	$count = 0;
	foreach my $element ($firefox->find_by_class('navbar navbar-default')->list_by_link('API')) {
		ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with list_by_link");
		$count += 1;
	}
	SKIP: {
		if (($count == 0) && ($major_version < 50)) {
			chomp $@;
			diag("Nested list_by_link can break for $major_version.$minor_version.$patch_version:$@");
			skip("Nested list_by_link can break for $major_version.$minor_version.$patch_version", 2);
		}
		ok($count == 1, "Found elements with nested list_by_link:$count");
	}
	$count = 0;
	foreach my $element ($firefox->find_by_class('container-fluid')->find_by_link('API')) {
		ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with find_by_link");
		$count += 1;
	}
	SKIP: {
		if (($count == 0) && ($major_version < 50)) {
			chomp $@;
			diag("Nested find_by_link can break for $major_version.$minor_version.$patch_version:$@");
			skip("Nested find_by_link can break for $major_version.$minor_version.$patch_version", 2);
		}
		ok($count == 1, "Found elements with nested find_by_link:$count");
	}
	$count = 0;
	foreach my $element ($firefox->find_by_link('API')) {
		ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found wantarray element with find_by_link");
		$count += 1;
	}
	if (($count == 1) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for find_by_link", 2);
		}
	} else {
		ok($count == 2, "Found elements with wantarray find_by_link:$count");
	}
	$count = 0;
	foreach my $element ($firefox->find_link('API')) {
		ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found wantarray element with find_link");
		$count += 1;
	}
	if (($count == 1) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for find_link", 2);
		}
	} else {
		ok($count == 2, "Found elements with wantarray find_link:$count");
	}
	ok($firefox->find('AP', 'partial link text')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element when searching by partial link text");
	ok($firefox->find('AP', BY_PARTIAL())->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element when searching by partial link text");
	ok($firefox->list_by_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with list_by_partial");
	ok($firefox->find_by_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with find_by_partial");
	ok($firefox->find_by_class('container-fluid')->find_by_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with find_by_partial");
	ok($firefox->find_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with find_partial");
	ok($firefox->has_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found element with has_partial");
	ok($firefox->find_class('container-fluid')->find_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with find_partial");
	ok($firefox->has_class('container-fluid')->has_partial('AP')->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with has_partial");
	$count = 0;
	foreach my $element ($firefox->find_by_class('container-fluid')->list_by_partial('AP')) {
		if ($count == 0) {
			ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with list_by_partial");
		}
		$count +=1;
	}
	if (($count == 2) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for list_by_partial", 1);
		}
	} else {
		ok($count == 1, "Found elements with nested list_by_partial:$count");
	}
	$count = 0;
	foreach my $element ($firefox->find_by_class('container-fluid')->find_by_partial('AP')) {
		if ($count == 0) {
			ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found nested element with find_by_partial");
		}
		$count +=1;
	}
	if (($count == 2) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for find_by_partial", 1);
		}
	} else {
		ok($count == 1, "Found elements with nested find_by_partial:$count");
	}
	$count = 0;
	foreach my $element ($firefox->find_by_partial('AP')) {
		ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found wantarray element with find_by_partial");
		$count +=1;
	}
	ok($count == 2, "Found elements with wantarray find_by_partial:$count");
	$count = 0;
	foreach my $element ($firefox->find_partial('AP')) {
		ok($element->attribute('href') =~ /^https:\/\/fastapi[.]metacpan[.]org\/?$/smx, "Correctly found wantarray element with find_partial");
		$count +=1;
	}
	ok($count == 2, "Found elements with wantarray find_partial:$count");
	my $css_rule;
	ok($css_rule = $firefox->find('//input[@id="search-input"]')->css('display'), "The value of the css rule 'display' is '$css_rule'");
	my $result;
	ok($result = $firefox->find('//input[@id="search-input"]')->is_enabled() =~ /^[01]$/, "is_enabled returns 0 or 1:$result");
	eval { $firefox->is_enabled({}) };
	my $eval_string = "$@";
	chomp $eval_string;
	ok((ref $@ eq 'Firefox::Marionette::Exception'), "is_enabled throws exception for bad parameters:$eval_string");
	ok($result = $firefox->find('//input[@id="search-input"]')->is_displayed() =~ /^[01]$/, "is_displayed returns 0 or 1:$result");
	eval { $firefox->is_displayed({}) };
	$eval_string = "$@";
	chomp $eval_string;
	ok((ref $@ eq 'Firefox::Marionette::Exception'), "is_displayed throws exception for bad parameters:$eval_string");
	ok($result = $firefox->find('//input[@id="search-input"]')->is_selected() =~ /^[01]$/, "is_selected returns 0 or 1:$result");
	eval { $firefox->is_selected({}) };
	$eval_string = "$@";
	chomp $eval_string;
	ok((ref $@ eq 'Firefox::Marionette::Exception'), "is_selected throws exception for bad parameters:$eval_string");
	ok($firefox->find('//input[@id="search-input"]')->clear(), "Clearing the element directly");
	TODO: {
		local $TODO = $major_version < 50 ? "property and attribute methods can have different values for empty" : undef;
		ok((!defined $firefox->find_id('search-input')->attribute('value')) && ($firefox->find_id('search-input')->property('value') eq ''), "Initial property and attribute values are empty for 'search-input'");
	}
	ok($firefox->find('//input[@id="search-input"]')->send_keys('Test::More'), "Sent 'Test::More' to the 'search-input' field directly to the element");
	TODO: {
		local $TODO = $major_version < 50 ? "attribute method can have different values for empty" : undef;
		ok(!defined $firefox->find_id('search-input')->attribute('value'), "attribute for 'search-input' is still not defined ");
	}
	my $property;
	eval {
		$property = $firefox->find_id('search-input')->property('value');
	};
	SKIP: {
		if ((!$property) && ($major_version < 50)) {
			chomp $@;
			diag("The property method is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("The property method is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		ok($property eq 'Test::More', "property for 'search-input' is now 'Test::More'");
	}
	ok($firefox->find('//input[@id="search-input"]')->clear(), "Clearing the element directly");
	foreach my $element ($firefox->find_elements('//input[@id="search-input"]')) {
		ok($firefox->send_keys($element, 'Test::More'), "Sent 'Test::More' to the 'search-input' field via the browser");
		ok($firefox->clear($element), "Clearing the element via the browser");
		ok($firefox->type($element, 'Test::More'), "Sent 'Test::More' to the 'search-input' field via the browser");
		last;
	}
	my $text = $firefox->find('//button[@name="lucky"]')->text();
	ok($text, "Read '$text' directly from 'Lucky' button");
	my $tag_name = $firefox->find('//button[@name="lucky"]')->tag_name();
	ok($tag_name, "'Lucky' button has a tag name of '$tag_name'");
	my $rect;
	eval {
		$rect = $firefox->find('//button[@name="lucky"]')->rect();
	};
	SKIP: {
		if (($major_version < 50) && (!defined $rect)) {
			skip("Firefox $major_version does not appear to support the \$firefox->window_rect() method", 4);
		}
		ok($rect->pos_x() =~ /^\d+([.]\d+)?$/, "'Lucky' button has a X position of " . $rect->pos_x());
		ok($rect->pos_y() =~ /^\d+([.]\d+)?$/, "'Lucky' button has a Y position of " . $rect->pos_y());
		ok($rect->width() =~ /^\d+([.]\d+)?$/, "'Lucky' button has a width of " . $rect->width());
		ok($rect->height() =~ /^\d+([.]\d+)?$/, "'Lucky' button has a height of " . $rect->height());
	}
	ok(((scalar $firefox->cookies()) >= 0), "\$firefox->cookies() shows cookies on " . $firefox->uri());
	ok($firefox->delete_cookies() && ((scalar $firefox->cookies()) == 0), "\$firefox->delete_cookies() clears all cookies");
	my $capabilities = $firefox->capabilities();
	my $buffer = undef;
	ok($firefox->selfie(raw => 1) =~ /^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A/smx, "\$firefox->selfie(raw => 1) returns a PNG image");
	my $handle = $firefox->selfie();
	$handle->read($buffer, 20);
	ok($buffer =~ /^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A/smx, "\$firefox->selfie() returns a PNG file");
	$buffer = undef;
	$handle = $firefox->find('//button[@name="lucky"]')->selfie();
	ok(ref $handle eq 'File::Temp', "\$firefox->selfie() returns a File::Temp object");
	$handle->read($buffer, 20);
	ok($buffer =~ /^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A/smx, "\$firefox->find('//button[\@name=\"lucky\"]')->selfie() returns a PNG file");
	if ($major_version < 31) {
		SKIP: {
			skip("Firefox before 31 can hang when processing the hash parameter", 3);
		}
	} else {
		my $actual_digest = $firefox->selfie(hash => 1, highlights => [ $firefox->find('//button[@name="lucky"]') ]);
		SKIP: {
			if (($major_version < 50) && ($actual_digest !~ /^[a-f0-9]+$/smx)) {
				skip("Firefox $major_version does not appear to support the hash parameter for the \$firefox->selfie method", 1);
			}
			ok($actual_digest =~ /^[a-f0-9]+$/smx, "\$firefox->selfie(hash => 1, highlights => [ \$firefox->find('//button[\@name=\"lucky\"]') ]) returns a hex encoded SHA256 digest");
		}
		$handle = $firefox->selfie(highlights => [ $firefox->find('//button[@name="lucky"]') ]);
		$buffer = undef;
		$handle->read($buffer, 20);
		ok($buffer =~ /^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A/smx, "\$firefox->selfie(highlights => [ \$firefox->find('//button[\@name=\"lucky\"]') ]) returns a PNG file");
		$handle->seek(0,0) or die "Failed to seek:$!";
		$handle->read($buffer, 1_000_000) or die "Failed to read:$!";
		my $correct_digest = Digest::SHA::sha256_hex(MIME::Base64::encode_base64($buffer, q[]));
		TODO: {
			local $TODO = "Digests can sometimes change for all platforms";
			ok($actual_digest eq $correct_digest, "\$firefox->selfie(hash => 1, highlights => [ \$firefox->find('//button[\@name=\"lucky\"]') ]) returns the correct hex encoded SHA256 hash of the base64 encoded image");
		}
	}
	my $clicked;
	my @elements = $firefox->find('//a[@href="https://fastapi.metacpan.org"]');
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 61);
	}
	ELEMENTS: {
		foreach my $element (@elements) {
			if ($major_version < 31) {
				eval {
					if (($element->is_displayed()) && ($element->is_enabled())) {
						$element->click();
						$clicked = 1;
					}
				};
			} else {
				if (($element->is_displayed()) && ($element->is_enabled())) {
					$element->click();
					$clicked = 1;
				}
			}
			if ($clicked) {
				if ($major_version < 31) {
					if ($firefox->uri()->host() eq 'github.com') {
						last ELEMENTS;
					} else {
						sleep 2;
						redo ELEMENTS;
					}
				} else {
					last ELEMENTS;
				}
			}
		}
	}
	ok($clicked, "Clicked the API link");
	$firefox->sleep_time_in_ms(1_000);
	ok($firefox->await(sub { $firefox->uri()->host() eq 'github.com' }), "\$firefox->uri()->host() is equal to github.com:" . $firefox->uri());
	while(!$firefox->loaded()) {
		diag("Waiting for firefox to load after clicking on API link");
		sleep 1;
	}
	my @cookies = $firefox->cookies();
	ok($cookies[0]->name() =~ /\w/, "The first cookie name is '" . $cookies[0]->name() . "'");
	ok($cookies[0]->value() =~ /\w/, "The first cookie value is '" . $cookies[0]->value() . "'");
	TODO: {
		local $TODO = ($major_version < 56) ? "\$cookies[0]->expiry() does not function for Firefox versions less than 56" : undef;
		if (defined $cookies[0]->expiry()) {
			ok($cookies[0]->expiry() =~ /^\d+$/, "The first cookie name has an integer expiry date of '" . ($cookies[0]->expiry() || q[]) . "'");
		} else {
			ok(1, "The first cookie is a session cookie");
		}
	}
	ok($cookies[0]->http_only() =~ /^[01]$/, "The first cookie httpOnly flag is a boolean set to '" . $cookies[0]->http_only() . "'");
	ok($cookies[0]->secure() =~ /^[01]$/, "The first cookie secure flag is a boolean set to '" . $cookies[0]->secure() . "'");
	ok($cookies[0]->path() =~ /\S/, "The first cookie path is a string set to '" . $cookies[0]->path() . "'");
	ok($cookies[0]->domain() =~ /^[\w\-.]+$/, "The first cookie domain is a domain set to '" . $cookies[0]->domain() . "'");
	if (defined $cookies[0]->same_site()) {
		ok($cookies[0]->same_site() =~ /^(Lax|Strict|None)$/, "The first cookie same-site value is legal '" . $cookies[0]->same_site() . "'");
	} else {
		diag("Possible no same-site support for $major_version.$minor_version.$patch_version");
		ok(1, "The first cookie same-site value is not present");
	}
	my $original_number_of_cookies = scalar @cookies;
	ok(($original_number_of_cookies > 1) && ((ref $cookies[0]) eq 'Firefox::Marionette::Cookie'), "\$firefox->cookies() returns more than 1 cookie on " . $firefox->uri());
	ok($firefox->delete_cookie($cookies[0]->name()), "\$firefox->delete_cookie('" . $cookies[0]->name() . "') deletes the specified cookie name");
	ok(not(grep { $_->name() eq $cookies[0]->name() } $firefox->cookies()), "List of cookies no longer includes " . $cookies[0]->name());
	ok($firefox->back(), "\$firefox->back() goes back one page");
	while(!$firefox->loaded()) {
		diag("Waiting for firefox to load after clicking back button");
		sleep 1;
	}
	while($firefox->uri()->host() ne 'metacpan.org') {
		diag("Waiting to load previous page:" . $firefox->uri()->host());
		sleep 1;
	}
	ok($firefox->uri()->host() eq 'metacpan.org', "\$firefox->uri()->host() is equal to metacpan.org:" . $firefox->uri());
	ok($firefox->forward(), "\$firefox->forward() goes forward one page");
	while(!$firefox->loaded()) {
		diag("Waiting for firefox to load after clicking forward button");
		sleep 1;
	}
	while($firefox->uri()->host() ne 'github.com') {
		diag("Waiting to load next page:" . $firefox->uri()->host());
		sleep 1;
	}
	ok($firefox->uri()->host() eq 'github.com', "\$firefox->uri()->host() is equal to github.com:" . $firefox->uri());
	ok($firefox->back(), "\$firefox->back() goes back one page");
	while(!$firefox->loaded()) {
		diag("Waiting for firefox to load after clicking back button (2)");
		sleep 1;
	}
	while($firefox->uri()->host() ne 'metacpan.org') {
		diag("Waiting to load previous page (2):" . $firefox->uri()->host());
		sleep 1;
	}
	ok($firefox->uri()->host() eq 'metacpan.org', "\$firefox->uri()->host() is equal to metacpan.org:" . $firefox->uri());
	my %additional;
	if ($major_version >= 64) {
		$additional{sandbox} = 'system';
	}
	ok($firefox->script('return true;', %additional), "javascript command 'return true' executes successfully");
	ok($firefox->script('return true', timeout => 10_000, new => 1, %additional), "javascript command 'return true' (using timeout and new (true) as parameters)");
	ok($firefox->script('return true', scriptTimeout => 20_000, newSandbox => 0, %additional), "javascript command 'return true' (using scriptTimeout and newSandbox (false) as parameters)");
	my $cookie = Firefox::Marionette::Cookie->new(name => 'BonusCookie', value => 'who really cares about privacy', expiry => time + 500000);
	ok($firefox->add_cookie($cookie), "\$firefox->add_cookie() adds a Firefox::Marionette::Cookie without a domain");
	$cookie = Firefox::Marionette::Cookie->new(name => 'BonusSessionCookie', value => 'will go away anyway');
	ok($firefox->add_cookie($cookie), "\$firefox->add_cookie() adds a Firefox::Marionette::Cookie without expiry");
	ok($firefox->find_id('search-input')->clear()->find_id('search-input')->type('Test::More'), "Sent 'Test::More' to the 'search-input' field directly to the element");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 36);
	}
	ok($firefox->find_name('lucky')->click($element), "Clicked the \"I'm Feeling Lucky\" button");
	diag("Going to Test::More page with a page load strategy of " . ($capabilities->page_load_strategy() || ''));
	SKIP: {
		if ($major_version < 45) {
			skip("Firefox below 45 (at least 24) does not support the getContext method", 5);
		}
		if (($major_version <= 63) && ($ENV{FIREFOX_VISIBLE})) {
			skip("Firefox below 63 are having problems with Xvfb", 5);
		}
		ok($firefox->bye(sub { $firefox->find_id('not-there-at-all') })->await(sub { $firefox->interactive() && $firefox->find_partial('Download'); })->click(), "Clicked on the download link");
		diag("Clicked download link");
		while(!$firefox->downloads()) {
			sleep 1;
		}
		while($firefox->downloading()) {
			sleep 1;
		}
		$count = 0;
		my $download_path;
		foreach my $path ($firefox->downloads()) {
			diag("Downloaded $path");
			if ($path =~ /Test\-Simple/) { # dodging possible Devel::Cover messages
				$download_path = $path;
				$count += 1;
			} elsif ($INC{'Devel/Cover.pm'}) {
			} else {
				$count += 1;
			}
		}
		ok($count == 1, "Downloaded 1 files:$count");
		my $handle = $firefox->download($download_path);
		ok($handle->isa('GLOB'), "Obtained GLOB from \$firefox->download(\$path)");
		if ($INC{'Devel/Cover.pm'}) {
		} else {
			my $gz = Compress::Zlib::gzopen($handle, 'rb') or die "Failed to open gzip stream";
			my $bytes_read = 0;
			while($gz->gzread(my $buffer, 4096)) {
				$bytes_read += length $buffer
			}
			ok($bytes_read > 1_000, "Downloaded file is gzipped");
		}
	}
	$firefox->go('http://www.example.com');
	my $body = $firefox->find("//body");
	my $outer_html = $firefox->script(q{ return arguments[0].outerHTML;}, args => [$body]);
	ok($outer_html =~ /<body>/smx, "Correctly passing found elements into script arguments");
	$outer_html = $firefox->script(q{ return arguments[0].outerHTML;}, args => $body);
	ok($outer_html =~ /<body>/smx, "Converts a single argument into an array");
	my $link = $firefox->find('//a');
	$firefox->script(q{arguments[0].parentNode.removeChild(arguments[0]);}, args => [$link]);
	eval {
		$link->attribute('href');
	};
	ok($@->isa('Firefox::Marionette::Exception::StaleElement') && $@ =~ /stale/smxi, "Correctly throws useful stale element exception");
	ok($@->status() || 1, "Firefox::Marionette::Exception::Response->status() is callable:" . ($@->status() || q[]));
	ok($@->message(), "Firefox::Marionette::Exception::Response->message() is callable:" . $@->message());
	ok($@->error() || 1, "Firefox::Marionette::Exception::Response->error() is callable:" . ($@->error() || q[]));
	ok($@->trace() || 1, "Firefox::Marionette::Exception::Response->trace() is callable");

	my $alert_text = 'testing alert';
	SKIP: {
		if ($major_version < 50) {
			skip("Firefox $major_version may hang when executing \$firefox->script(qq[alert(...)])", 2);
		}
		$firefox->script(qq[alert('$alert_text')]);
		ok($firefox->alert_text() eq $alert_text, "\$firefox->alert_text() correctly detects alert text");
		ok($firefox->dismiss_alert(), "\$firefox->dismiss_alert() dismisses alert box");
	}
	my $version = $capabilities->browser_version();
	my ($major_version, $minor_version, $patch_version) = split /[.]/, $version;
	ok($firefox->async_script(qq[prompt("Please enter your name", "John Cole");]), "Started async script containing a prompt");
	my $send_alert_text;
	eval {
		$send_alert_text = $firefox->await(sub { $firefox->send_alert_text("Roland Grelewicz"); });
	};
	SKIP: {
		if (($major_version < 50) && (!defined $send_alert_text)) {
			skip("Firefox $major_version does not appear to support the \$firefox->send_alert_text() method", 1);
		}
		ok($send_alert_text, "\$firefox->send_alert_text() sends alert text:$@");
	}
	my $accept_dialog;
	eval {
		$accept_dialog = $firefox->accept_dialog();
	};
	SKIP: {
		if (($major_version < 50) && (!defined $accept_dialog)) {
			skip("Firefox $major_version does not appear to support the \$firefox->send_alert_text() method", 1);
		}
		ok($accept_dialog, "\$firefox->accept_dialog() accepts the dialog box");
	}
	SKIP: {
		if ((!$chrome_window_handle_supported) && ($major_version < 50)) {
			diag("\$firefox->current_chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->current_chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		ok($firefox->current_chrome_window_handle() =~ /^\d+$/, "Returned the current chrome window handle as an integer");
	}
	$capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!grep /^page_load_strategy$/, $capabilities->enumerate()) {
			diag("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->page_load_strategy() =~ /^\w+$/, "\$capabilities->page_load_strategy() is a string:" . $capabilities->page_load_strategy());
	}
	ok($capabilities->moz_headless() =~ /^(1|0)$/, "\$capabilities->moz_headless() is a boolean:" . $capabilities->moz_headless());
	SKIP: {
		if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
			diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->accept_insecure_certs() =~ /^(1|0)$/, "\$capabilities->accept_insecure_certs() is a boolean:" . $capabilities->accept_insecure_certs());
	}
	SKIP: {
		if (!grep /^moz_process_id$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_process_id is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_process_id is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_process_id() =~ /^\d+$/, "\$capabilities->moz_process_id() is an integer:" . $capabilities->moz_process_id());
	}
	SKIP: {
		if (!grep /^moz_build_id$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_build_id is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_build_id is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_build_id() =~ /^\d{14}$/, "\$capabilities->moz_build_id() is an date/timestamp:" . $capabilities->moz_build_id());
	}
	ok($capabilities->browser_name() =~ /^\w+$/, "\$capabilities->browser_name() is a string:" . $capabilities->browser_name());
	ok($capabilities->rotatable() =~ /^(1|0)$/, "\$capabilities->rotatable() is a boolean:" . $capabilities->rotatable());
	SKIP: {
		if (!grep /^moz_use_non_spec_compliant_pointer_origin$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_use_non_spec_compliant_pointer_origin is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_use_non_spec_compliant_pointer_origin is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_use_non_spec_compliant_pointer_origin() =~ /^(1|0)$/, "\$capabilities->moz_use_non_spec_compliant_pointer_origin() is a boolean:" . $capabilities->moz_use_non_spec_compliant_pointer_origin());
	}
	SKIP: {
		if (!grep /^moz_accessibility_checks$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_accessibility_checks is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_accessibility_checks is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_accessibility_checks() =~ /^(1|0)$/, "\$capabilities->moz_accessibility_checks() is a boolean:" . $capabilities->moz_accessibility_checks());
	}
	ok((ref $capabilities->timeouts()) eq 'Firefox::Marionette::Timeouts', "\$capabilities->timeouts() returns a Firefox::Marionette::Timeouts object");
	ok($capabilities->timeouts()->page_load() =~ /^\d+$/, "\$capabilities->timeouts->page_load() is an integer:" . $capabilities->timeouts()->page_load());
	ok($capabilities->timeouts()->script() =~ /^\d+$/, "\$capabilities->timeouts->script() is an integer:" . $capabilities->timeouts()->script());
	ok($capabilities->timeouts()->implicit() =~ /^\d+$/, "\$capabilities->timeouts->implicit() is an integer:" . $capabilities->timeouts()->implicit());
	ok($capabilities->browser_version() =~ /^\d+[.]\d+(?:[a]\d+)?([.]\d+)?$/, "\$capabilities->browser_version() is a major.minor.patch version number:" . $capabilities->browser_version());
	TODO: {
		local $TODO = ($major_version < 31) ? "\$capabilities->platform_version() may not exist for Firefox versions less than 31" : undef;
		ok(defined $capabilities->platform_version() && $capabilities->platform_version() =~ /\d+/, "\$capabilities->platform_version() contains a number:" . ($capabilities->platform_version() || ''));
	}
	ok($capabilities->moz_profile() =~ /firefox_marionette/, "\$capabilities->moz_profile() contains 'firefox_marionette':" . $capabilities->moz_profile());
	SKIP: {
		if (!grep /^moz_webdriver_click$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_webdriver_click is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_webdriver_click is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_webdriver_click() =~ /^(1|0)$/, "\$capabilities->moz_webdriver_click() is a boolean:" . $capabilities->moz_webdriver_click());
	}
	ok($capabilities->platform_name() =~ /\w+/, "\$capabilities->platform_version() contains alpha characters:" . $capabilities->platform_name());
	eval {
		$firefox->dismiss_alert();
	};
	my $exception = "$@";
	chomp $exception;
	ok($@, "Dismiss non-existant alert caused an exception to be thrown:$exception");
	$count = 0;
	$result = undef;
	foreach my $path (qw(t/addons/test.xpi t/addons/discogs-search t/addons/discogs-search/manifest.json t/addons/discogs-search/)) {
		$count += 1;
		if ($major_version < 56) {
			if ($path =~ /discogs/) {
				next;
			}
		}
		my $install_id;
		my $install_path = Cwd::abs_path($path);
		diag("Original install path is $install_path");
		if ($^O eq 'MSWin32') {
			$install_path =~ s/\//\\/smxg;
		}
		diag("Installing extension from $install_path");
		my $temporary = 1;
		if ($firefox->nightly()) {
			$temporary = $count % 2 ? 1 : 0;
		}
		eval {
			$install_id = $firefox->install($install_path, $temporary);
		};
		SKIP: {	
			my $exception = "$@";
			chomp $exception;
			if ((!$install_id) && ($major_version < 52)) {
				skip("addon:install may not be supported in firefox versions less than 52:$exception", 2);
			}
			ok($install_id, "Successfully installed an extension:$install_id");
			ok($firefox->uninstall($install_id), "Successfully uninstalled an extension");
		}
		$result = undef;
		$install_id = undef;
		$install_path = $path;
		diag("Original install path is $install_path");
		if ($^O eq 'MSWin32') {
			$install_path =~ s/\//\\/smxg;
		}
		diag("Installing extension from $install_path");
		eval {
			$install_id = $firefox->install($install_path, $temporary);
		};
		SKIP: {	
			my $exception = "$@";
			chomp $exception;
			if ((!$install_id) && ($major_version < 52)) {
				skip("addon:install may not be supported in firefox versions less than 52:$exception", 2);
			}
			ok($install_id, "Successfully installed an extension:$install_id");
			ok($firefox->uninstall($install_id), "Successfully uninstalled an extension");
		}
		$result = undef;
	}
	eval {
		$result = $firefox->accept_connections(0);
	};
	SKIP: {
		my $exception = "$@";
		chomp $exception;
		if ((!$result) && ($major_version < 52)) {
			skip("Refusing future connections may not be supported in firefox versions less than 52:$exception", 1);
		}
		ok($result, "Refusing future connections");
	}
	ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
}

SKIP: {
	($skip_message, $firefox) = start_firefox(0, visible => 0, debug => 1, implicit => 987654);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 8);
	}
	ok($firefox, "Firefox has started in Marionette mode with visible set to 0");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	TODO: {
		local $TODO = $major_version < 60 ? "\$capabilities->moz_headless() may not be available for Firefox versions less than 60" : undef;
		ok($capabilities->moz_headless() || $ENV{FIREFOX_VISIBLE} || 0, "\$capabilities->moz_headless() is set to " . ($ENV{FIREFOX_VISIBLE} ? 'false' : 'true'));
	}
        ok($capabilities->timeouts()->implicit() == 987654, "\$firefox->capabilities()->timeouts()->implicit() correctly reflects the implicit shortcut timeout");
	my $daemon = HTTP::Daemon->new(LocalAddr => 'localhost') || die "Failed to create HTTP::Daemon";
	SKIP: {
		if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
			diag("\$capabilities->proxy is not supported for remote hosts");
			skip("\$capabilities->proxy is not supported for remote hosts", 3);
		} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
			diag("\$capabilities->proxy is not supported for remote hosts");
			skip("\$capabilities->proxy is not supported for remote hosts", 3);
		} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
			my $json_document = Encode::decode('UTF-8', '{ "id": "5", "value": "sömething"}');
			my $txt_document = 'This is ordinary text';
			if (my $pid = fork) {
				$firefox->go($daemon->url() . '?format=JSON');
				ok($firefox->strip() eq $json_document, "Correctly retrieved JSON document");
				diag($firefox->strip());
				ok($firefox->json()->{id} == 5, "Correctly parsed JSON document");
				ok(Encode::encode('UTF-8', $firefox->json()->{value}, 1) eq "sömething", "Correctly parsed UTF-8 JSON field");
				$firefox->go($daemon->url() . '?format=txt');
				ok($firefox->strip() eq $txt_document, "Correctly retrieved TXT document");
				diag($firefox->strip());
				while(kill 0, $pid) {
					kill $signals_by_name{TERM}, $pid;
					sleep 1;
					waitpid $pid, POSIX::WNOHANG();
				}
			} elsif (defined $pid) {
				eval {
					local $SIG{ALRM} = sub { die "alarm during content server\n" };
					alarm 40;
					$0 = "[Test HTTP Content Server for " . getppid . "]";
					while (my $connection = $daemon->accept()) {
						diag("Accepted connection");
						if (my $child = fork) {
						} elsif (defined $child) {
							eval {
								local $SIG{ALRM} = sub { die "alarm during content server accept\n" };
								alarm 40;
								while (my $request = $connection->get_request()) {
									diag("Got request for " . $request->uri());
									my ($headers, $response);
									if ($request->uri() =~ /format=JSON/) {
										$headers = HTTP::Headers->new('Content-Type', 'application/json; charset=utf-8');
										$response = HTTP::Response->new(200, "OK", $headers, Encode::encode('UTF-8', $json_document, 1));
									} elsif ($request->uri() =~ /format=txt/) {
										$headers = HTTP::Headers->new('Content-Type', 'text/plain');
										$response = HTTP::Response->new(200, "OK", $headers, $txt_document);
									} else {
										$response = HTTP::Response->new(200, "OK", undef, 'hello world');
									}
									$connection->send_response($response);
									if ($request->uri() =~ /format=JSON/) {
										last;
									} elsif ($request->uri() =~ /format=txt/) {
										last;
									}
								}
								$connection->close;
								$connection = undef;
								exit 0;
							} or do {
								chomp $@;
								diag("Caught exception in content server accept:$@");
							};
							exit 1;
						} else {
							diag("Failed to fork connection:$!");
							die "Failed to fork:$!";
						}
					}
				} or do {
					chomp $@;
					diag("Caught exception in content server:$@");
				};
				exit 1;
			} else {
				diag("Failed to fork http proxy:$!");
				die "Failed to fork:$!";
			}
		} else {
			skip("No forking available for $^O", 3);
			diag("No forking available for $^O");
		}
	}
	local $TODO = $major_version == 60 ? "Not entirely stable in firefox 60" : q[];
	ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
}

SKIP: {
	my $proxy_host = 'all.example.org';
	($skip_message, $firefox) = start_firefox(1, console => 1, debug => 1, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 0, accept_insecure_certs => 0, page_load_strategy => 'none', moz_webdriver_click => 0, moz_accessibility_checks => 0, proxy => Firefox::Marionette::Proxy->new(host => $proxy_host)), timeouts => Firefox::Marionette::Timeouts->new(page_load => 78_901, script => 76_543, implicit => 34_567));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 32);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to different values");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
        ok($capabilities->timeouts()->page_load() == 78_901, "\$firefox->capabilities()->timeouts()->page_load() correctly reflects the timeouts shortcut timeout");
        ok($capabilities->timeouts()->script() == 76_543, "\$firefox->capabilities()->timeouts()->script() correctly reflects the timeouts shortcut timeout");
        ok($capabilities->timeouts()->implicit() == 34_567, "\$firefox->capabilities()->timeouts()->implicit() correctly reflects the timeouts shortcut timeout");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'manual', "\$capabilities->proxy()->type() is 'manual'");
		ok($capabilities->proxy()->ftp() eq "$proxy_host:80", "\$capabilities->proxy()->ftp() is '$proxy_host:80'");
		ok($capabilities->proxy()->http() eq "$proxy_host:80", "\$capabilities->proxy()->http() is '$proxy_host:80'");
		ok($capabilities->proxy()->https() eq "$proxy_host:80", "\$capabilities->proxy()->https() is '$proxy_host:80'");
	}
	SKIP: {
		if (!grep /^page_load_strategy$/, $capabilities->enumerate()) {
			diag("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->page_load_strategy() eq 'none', "\$capabilities->page_load_strategy() is 'none'");
	}
	SKIP: {
		if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
			diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->accept_insecure_certs() == 0, "\$capabilities->accept_insecure_certs() is set to false");
	}
	SKIP: {
		if (!grep /^moz_use_non_spec_compliant_pointer_origin$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_use_non_spec_compliant_pointer_origin is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_use_non_spec_compliant_pointer_origin is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_use_non_spec_compliant_pointer_origin() == 0, "\$capabilities->moz_use_non_spec_compliant_pointer_origin() is set to false");
	}
	SKIP: {
		if (!grep /^moz_webdriver_click$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_webdriver_click is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_webdriver_click is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_webdriver_click() == 0, "\$capabilities->moz_webdriver_click() is set to false");
	}
	SKIP: {
		if (!grep /^moz_accessibility_checks$/, $capabilities->enumerate()) {
			diag("\$capabilities->moz_accessibility_checks is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->moz_accessibility_checks is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->moz_accessibility_checks() == 0, "\$capabilities->moz_accessibility_checks() is set to false");
	}
	SKIP: {
		if ($ENV{FIREFOX_HOST}) {
			diag("\$capabilities->headless is forced on for FIREFOX_HOST testing");
			skip("\$capabilities->headless is forced on for FIREFOX_HOST testing", 1);
		}
		ok(not($capabilities->moz_headless()), "\$capabilities->moz_headless() is set to false");
	}
	SKIP: {
		if ($major_version < 66) {
			skip("Firefox $major_version does not support \$firefox->new_window()", 15);
		}
		if ($firefox->capabilities()->browser_name() eq 'waterfox') {
			skip("Waterfox does not support \$firefox->new_window()", 15);
		}
		ok(scalar $firefox->window_handles() == 1, "The number of window handles is currently 1");
		my ($old_window) = $firefox->window_handles();
		my $new_window = $firefox->new_window();
		ok(check_for_window($firefox, $new_window), "\$firefox->new_window() has created a new tab");
		ok($firefox->switch_to_window($new_window), "\$firefox->switch_to_window(\$new_window) has switched focus to new tab");
		ok($firefox->close_current_window_handle(), "Closed new tab");
		ok(!check_for_window($firefox, $new_window), "\$firefox->new_window() has closed ");
		ok($firefox->switch_to_window($old_window), "\$firefox->switch_to_window(\$old_window) has switched focus to original window");
		$new_window = $firefox->new_window(focus => 1, type => 'window', private => 1);
		ok(check_for_window($firefox, $new_window), "\$firefox->new_window() has created a new in focus, private window");
		$firefox->switch_to_window($new_window);
		ok($firefox->close_current_window_handle(), "Closed new window");
		ok(!check_for_window($firefox, $new_window), "\$firefox->new_window() has been closed");
		ok($firefox->switch_to_window($old_window), "\$firefox->switch_to_window(\$old_window) has switched focus to original window");
		$new_window = $firefox->new_window(focus => 0, type => 'tab');
		ok(check_for_window($firefox, $new_window), "\$firefox->new_window() has created a new tab");
		ok($firefox->switch_to_window($new_window), "\$firefox->switch_to_window(\$new_window) has switched focus to new tab");
		ok($firefox->close_current_window_handle(), "Closed new tab");
		ok(!check_for_window($firefox, $new_window), "\$firefox->new_window() has been closed");
		ok(scalar $firefox->window_handles() == 1, "The number of window handles is currently 1");
		$firefox->switch_to_window($old_window);
	}
	my $alert_text = 'testing alert';
	SKIP: {
		if ($major_version < 50) {
			skip("Firefox $major_version may hang when executing \$firefox->script(qq[alert(...)])", 1);
		}
		$firefox->script(qq[alert('$alert_text')]);
		ok($firefox->accept_alert(), "\$firefox->accept_alert() accepts alert box");
	}
	ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
}

sub check_for_window {
	my ($firefox, $window_handle) = @_;
	if (defined $window_handle) {
		foreach my $existing_handle ($firefox->window_handles()) {
			if ($existing_handle == $window_handle) {
				return 1;
			} 
		}
	}
	return 0;
}

SKIP: {
	local %ENV = %ENV;
	my $localPort = 8080;
	$ENV{http_proxy} = 'https://localhost:' . $localPort;
	$ENV{https_proxy} = 'https://proxy2.example.org:4343';
	$ENV{ftp_proxy} = 'ftp://ftp2.example.org:2121';
	($skip_message, $firefox) = start_firefox(1, visible => 1, width => 800, height => 600);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 15);
	}
	ok($firefox, "Firefox has started in Marionette mode with visible set to 1");
	if ($firefox->xvfb_pid()) {
		diag("Internal old xvfb pid is " . $firefox->xvfb());
		diag("Internal xvfb pid is " . $firefox->xvfb_pid());
		ok($firefox->xvfb_pid(), "Internal xvfb PID is " . $firefox->xvfb_pid());
		diag("Internal xvfb DISPLAY is " . $firefox->xvfb_display());
		ok($firefox->xvfb_display(), "Internal xvfb DISPLAY is " . $firefox->xvfb_display());
		diag("Internal xvfb XAUTHORITY is " . $firefox->xvfb_xauthority());
		ok($firefox->xvfb_xauthority(), "Internal xvfb XAUTHORITY is " . $firefox->xvfb_xauthority());
	}
	my $window_rect;
	eval {
		$window_rect = $firefox->window_rect();
	};
	SKIP: {
		if (($major_version < 50) && (!defined $window_rect)) {
			skip("Firefox $major_version does not appear to support the \$firefox->window_rect() method", 2);
		}
		local $TODO = $^O eq 'linux' ? '' : "Initial width/height parameters not entirely stable in $^O";
		ok($window_rect->width() >= 800, "Window has a width of 800 (" . $window_rect->width() . ")");
		ok($window_rect->height() >= 600, "Window has a height of 600 (" . $window_rect->height() . ")");
		if (($window_rect->width() >= 800) && ($window_rect->height() >= 600)) {
		} else {
			diag("Width/Height for $^O set to 800x600, but returned " . $window_rect->width() . "x" . $window_rect->height());
		}
	}
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	ok(!$capabilities->moz_headless(), "\$capabilities->moz_headless() is set to false");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'manual', "\$capabilities->proxy()->type() is 'manual'");
		ok($capabilities->proxy()->http() eq 'localhost:' . $localPort, "\$capabilities->proxy()->http() is 'localhost:" . $localPort . "':" . $capabilities->proxy()->http());
		ok($capabilities->proxy()->https() eq 'proxy2.example.org:4343', "\$capabilities->proxy()->https() is 'proxy2.example.org:4343'");
		ok($capabilities->proxy()->ftp() eq 'ftp2.example.org:2121', "\$capabilities->proxy()->ftp() is 'ftp2.example.org:2121'");
	}
	SKIP: {
		if ((exists $ENV{XAUTHORITY}) && (defined $ENV{XAUTHORITY}) && ($ENV{XAUTHORITY} =~ /xvfb/smxi)) {
			skip("Unable to change firefox screen size when xvfb is running", 3);	
		} elsif ($firefox->xvfb_pid()) {
			skip("Unable to change firefox screen size when xvfb is running", 3);	
		}
		local $TODO = "Not entirely stable in firefox";
		my $full_screen;
		local $SIG{ALRM} = sub { die "alarm during full screen\n" };
		alarm 15;
		eval {
			$full_screen = $firefox->full_screen();
		} or do {
			diag("Crashed during \$firefox->full_screen:$@");
		};
		alarm 0;
		ok($full_screen, "\$firefox->full_screen()");
		my $minimise;
		local $SIG{ALRM} = sub { die "alarm during minimise\n" };
		alarm 15;
		eval {
			$minimise = $firefox->minimise();
		} or do {
			diag("Crashed during \$firefox->minimise:$@");
		};
		alarm 0;
		ok($minimise, "\$firefox->minimise()");
		my $maximise;
		local $SIG{ALRM} = sub { die "alarm during maximise\n" };
		alarm 15;
		eval {
			$maximise = $firefox->maximise();
		} or do {
			diag("Crashed during \$firefox->maximise:$@");
		};
		alarm 0;
		ok($maximise, "\$firefox->maximise()");
	}
	if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
		SKIP: {
			skip("Not testing dead firefox processes with ssh", 2);	
		}
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
		SKIP: {
			skip("Not testing dead firefox processes with ssh", 2);	
		}
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	} elsif (($^O eq 'MSWin32') || (!grep /^moz_process_id$/, $capabilities->enumerate())) {
		SKIP: {
			skip("Not testing dead firefox processes for win32/early firefox versions", 2);	
		}
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	} elsif ($^O eq 'cygwin') {
		SKIP: {
			skip("Not testing dead firefox processes for cygwin", 2);	
		}
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	} else {
		my $xvfb_pid = $firefox->xvfb_pid();
		while($firefox->alive()) {
			diag("Killing PID " . $capabilities->moz_process_id() . " with a signal " . $signals_by_name{TERM});
			sleep 1; 
			kill $signals_by_name{TERM}, $capabilities->moz_process_id();
			sleep 1; 
		}
		eval { $firefox->go('https://metacpan.org') };
		chomp $@;
		ok($@ =~ /Firefox[ ]killed[ ]by[ ]a[ ]TERM[ ]signal/smx, "Exception is thrown when a command is issued to a dead firefox process:$@");
		eval { $firefox->go('https://metacpan.org') };
		chomp $@;
		ok($@ =~ /Firefox[ ]killed[ ]by[ ]a[ ]TERM[ ]signal/smx, "Consistent exception is thrown when a command is issued to a dead firefox process:$@");
		ok($firefox->quit() == $signals_by_name{TERM}, "Firefox has been killed by a signal with value of $signals_by_name{TERM}:" . $firefox->child_error() . ":" . $firefox->error_message());
		diag("Error Message was " . $firefox->error_message());
		if (defined $xvfb_pid) {
			ok((!(kill 0, $xvfb_pid)) && ($! == POSIX::ESRCH()), "Xvfb process $xvfb_pid has been cleaned up:$!");
		} else {
			ok(1, "No Xvfb process exists");
		}
	}
}
SKIP: {
	if (($^O eq 'cygwin') ||
		($^O eq 'darwin') ||
		($^O eq 'MSWin32'))
	{
		skip("Skipping exit status tests on $^O", 2);
	} elsif (out_of_time()) {
		skip("Skipping exit status b/c out of time", 2);
	}
	my $exit_status = system { $^X } $^X, (map { "-I$_" } @INC), '-MFirefox::Marionette', '-e', 'my $f = Firefox::Marionette->new(); exit 0';
	ok($exit_status == 0, "Firefox::Marionette doesn't alter the exit code of the parent process if it isn't closed cleanly");
	$exit_status = system { $^X } $^X, (map { "-I$_" } @INC), '-MFirefox::Marionette', '-e', 'my $f = Firefox::Marionette->new(); $f = undef; exit 0';
	ok($exit_status == 0, "Firefox::Marionette doesn't alter the exit code of the parent process if it is 'undefed'");
}
ok($at_least_one_success, "At least one firefox start worked");
eval "no warnings; sub File::Temp::newdir { \$! = POSIX::EACCES(); return; } use warnings;";
ok(!$@, "File::Temp::newdir is redefined to fail:$@");
eval { Firefox::Marionette->new(); };
my $output = "$@";
chomp $output;
ok($@->isa('Firefox::Marionette::Exception') && $@ =~ / in .* at line \d+/, "When File::Temp::newdir is forced to fail, a Firefox::Marionette::Exception is thrown:$output");

done_testing();
