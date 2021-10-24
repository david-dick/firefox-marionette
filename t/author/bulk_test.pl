#! /usr/bin/perl

use strict;
use warnings;
use DirHandle();
use File::HomeDir();
use File::Spec();
use File::Temp();
use Cwd();
use POSIX();

if (exists $ENV{COUNT}) {
	$0 = "Test run number $ENV{COUNT}";
}
$ENV{RELEASE_TESTING} = 1;
$ENV{FIREFOX_ALARM} = 1;
my $cwd = Cwd::cwd();
our $pid;
if ($pid = fork) {
} elsif (defined $pid) {
	eval {
		exec { 'ping' } 'ping', '8.8.8.8' or die "Failed to exec ping:$!";
	} or do {
		print STDERR $@;
	};
	exit 1;
}
system { 'cover' } 'cover', '-delete' and die "Failed to 'cover' for " . ($ENV{FIREFOX_BINARY} || 'firefox');
my $path = File::Spec->catdir(File::HomeDir::my_home(), 'den');
my $initial_upgrade_package = 'firefox-52.0esr.tar.bz2';
my $initial_upgrade_directory = 'firefox-upgrade';
sub setup_upgrade {
	if (-e "$path/$initial_upgrade_package") {
		my $result = system "rm -Rf $path/firefox && rm -Rf $path/$initial_upgrade_directory && tar --directory $path -jxf $path/$initial_upgrade_package && mv $path/firefox $path/$initial_upgrade_directory";
		$result == 0 or die "Failed to setup $initial_upgrade_directory";
	}
}
setup_upgrade();
my $handle = DirHandle->new($path) or die "Failed to find firefox den at $path";
my @entries;
while(my $entry = $handle->read()) {
	next if ($entry eq File::Spec->updir());
	next if ($entry eq File::Spec->curdir());
	next if ($entry =~ /[.]tar[.]bz2$/smx);
	push @entries, $entry;
}
foreach my $entry (reverse sort { $a cmp $b } @entries) {
	my $entry_version;
	if ($entry =~ /^firefox\-([\d.]+)(?:esr|a\d+)?$/smx) {
		($entry_version) = ($1);
	} elsif ($entry eq 'firefox-nightly') {
	} elsif ($entry eq 'firefox-developer') {
	} elsif ($entry eq 'firefox-upgrade') {
	} elsif ($entry =~ /^waterfox/smx) {
	} else {
		die "Unrecognised entry '$entry' in $path";
	}
	if ($entry =~ /^waterfox/smx) {
	} elsif ($entry eq 'firefox-nightly') {
	} elsif ($entry eq 'firefox-developer') {
	} elsif ($entry eq 'firefox-upgrade') {
	} else {
		my $path_to_binary = File::Spec->catfile($path, $entry, 'firefox');
		my $old_version;
		my $old_output = `$path_to_binary --version 2>/dev/null`;
		if ($old_output =~ /^Mozilla[ ]Firefox[ ]([\d.]+)/smx) {
			($old_version) = ($1);
		} else {
			die "$path_to_binary old '$old_output' could not be parsed";
		}
		if ($old_version ne $entry_version) {
			die "$old_version does not equal $entry_version for $path_to_binary";
		}
	}
}
warn "Den is correct";
my %old_versions;
my %paths_to_binary;
ENTRY: foreach my $entry (reverse sort { $a cmp $b } @entries) {
	my $entry_version;
	if ($entry =~ /^waterfox/smx) {
	} elsif ($entry eq 'firefox-nightly') {
	} elsif ($entry eq 'firefox-developer') {
	} elsif ($entry eq 'firefox-upgrade') {
	} elsif ($entry =~ /^firefox\-([\d.]+)(?:esr|a\d+)?$/smx) {
		($entry_version) = ($1);
	} else {
		die "Unrecognised entry '$entry' in $path";
	}
	my $path_to_binary;
	if ($entry =~ /^waterfox/smx) {
		$path_to_binary = File::Spec->catfile($path, $entry, 'waterfox');
	} else {
		$path_to_binary = File::Spec->catfile($path, $entry, 'firefox');
	}
	$paths_to_binary{$entry} = $path_to_binary;
	my $old_version;
	my $old_output = `$path_to_binary --version 2>/dev/null`;
	if ($entry =~ /^waterfox/smx) {
		$old_version = $old_output;
	} elsif ($old_output =~ /^Mozilla[ ]Firefox[ ]([\d.]+)/smx) {
		($old_version) = ($1);
	} else {
		die "$path_to_binary old '$old_output' could not be parsed";
	}
	if ($entry =~ /^waterfox/smx) {
	} elsif ($entry eq 'firefox-nightly') {
	} elsif ($entry eq 'firefox-developer') {
	} elsif ($entry eq 'firefox-upgrade') {
	} elsif ($old_version ne $entry_version) {
		die "$old_version does not equal $entry_version for $path_to_binary";
	}
	$old_versions{$entry} = $old_version;
}
system { $^X } $^X, '-MDevel::Cover=-silent,1', '-Ilib', 't/01-marionette.t' and die "Failed to 'make'";
{
	local $ENV{FIREFOX_HOST} = 'localhost';
	warn "Remote Firefox for " . ($ENV{FIREFOX_BINARY} || 'firefox');
	system { $^X } $^X, '-MDevel::Cover=-silent,1', '-Ilib', 't/01-marionette.t' and die "Failed to 'make'";
}
if (my $entry = $old_versions{'firefox-upgrade'}) {
	setup_upgrade();
	if (defined $paths_to_binary{$entry}) {
		local $ENV{FIREFOX_BINARY} = $paths_to_binary{$entry};
		local $ENV{FIREFOX_HOST} = 'localhost';
		warn "Remote Firefox for " . $ENV{FIREFOX_BINARY};
		system { $^X } $^X, '-MDevel::Cover=-silent,1', '-Ilib', 't/01-marionette.t' and die "Failed to 'make'";
	}
}
ENTRY: foreach my $entry (reverse sort { $a cmp $b } @entries) {
	my $old_version = $old_versions{$entry};
	my $count = 0;
	my $path_to_binary = $paths_to_binary{$entry};
	$ENV{FIREFOX_BINARY} = $path_to_binary;
	my $reset_time = 600; # 10 minutes
	if ($entry =~ /^waterfox/smx) {
		WATERFOX: {
			local $ENV{WATERFOX} = 1;
			$count += 1;
			my $result = system { $^X } $^X, '-MDevel::Cover=-silent,1', '-Ilib', 't/01-marionette.t';
			if ($result != 0) {
				if ($count < 3) {
					warn "Failed '$^X -MDevel::Cover=-silent,1 -Ilib t/01-marionette' " . localtime . ".  Sleeping for $reset_time seconds for $path_to_binary";
					sleep $reset_time;
					redo WATERFOX;
				} else {
					die "Failed to make $count times";
				}
			}
		}
		WATERFOX_VIA_FIREFOX: {
			local $ENV{WATERFOX_VIA_FIREFOX} = 1;
			$count += 1;
			my $result = system { $^X } $^X, '-MDevel::Cover=-silent,1', '-Ilib', 't/01-marionette.t';
			if ($result != 0) {
				if ($count < 3) {
					warn "Failed '$^X -MDevel::Cover=-silent,1 -Ilib t/01-marionette' " . localtime . ".  Sleeping for $reset_time seconds for $path_to_binary";
					sleep $reset_time;
					redo WATERFOX_VIA_FIREFOX;
				} else {
					die "Failed to make $count times";
				}
			}
		}
	}
	if (-e $ENV{FIREFOX_BINARY}) {
		$count = 0;
		LOCAL: {
			$count += 1;
			my $result = system { $^X } $^X, '-MDevel::Cover=-silent,1', '-Ilib', 't/01-marionette.t';
			if ($result != 0) {
				if ($count < 3) {
					warn "Failed '$^X -MDevel::Cover=-silent,1 -Ilib t/01-marionette' " . localtime . ".  Sleeping for $reset_time seconds for $path_to_binary";
					if (($entry eq 'firefox-nightly') || ($entry eq 'firefox-developer')) {
						next ENTRY;
					}
					sleep $reset_time;
					redo LOCAL;
				} else {
					die "Failed to make $count times";
				}
			}
		}
		if ($entry eq 'firefox-upgrade') {
			setup_upgrade();
		}
		my $bash_command = 'cd ' . Cwd::cwd() . '; RELEASE_TESTING=1 FIREFOX_BINARY="' . $ENV{FIREFOX_BINARY} . "\" $^X -MDevel::Cover=-silent,1 -Ilib t/01-marionette.t";
		$count = 0;
		SSH: {
			$count += 1;
			warn "Remote Execution of '$bash_command'";
			my $result = system { 'ssh' } 'ssh', 'localhost', $bash_command;
			if ($result != 0) {
				if ($count < 3) {
					warn "Failed '$bash_command' " . localtime . ".  Sleeping for $reset_time seconds for $path_to_binary";
					if (($entry eq 'firefox-nightly') || ($entry eq 'firefox-developer')) {
						next ENTRY;
					}
					sleep $reset_time;
					redo SSH;
				} else {
					die "Failed to remote cover for $ENV{FIREFOX_BINARY} $count times"; 
				}
			}
		}
		if ($entry eq 'firefox-upgrade') {
			setup_upgrade();
		}
		$bash_command = 'cd ' . Cwd::cwd() . '; RELEASE_TESTING=1 FIREFOX_VISIBLE=1 FIREFOX_BINARY="' . $ENV{FIREFOX_BINARY} . "\" $^X -MDevel::Cover=-silent,1 -Ilib t/01-marionette.t";
		$count = 0;
		REMOTE_VISIBLE: {
			$count += 1;
			warn "Remote Execution of '$bash_command'";
			my $result = system { 'ssh' } 'ssh', 'localhost', $bash_command;
			if ($result != 0) {
				if ($count < 3) {
					warn "Failed '$bash_command' " . localtime . ".  Sleeping for $reset_time seconds for $path_to_binary";
					if (($entry eq 'firefox-nightly') || ($entry eq 'firefox-developer')) {
						next ENTRY;
					}
					sleep $reset_time;
					redo REMOTE_VISIBLE;
				} else {
					die "Failed to remote cover for visible $ENV{FIREFOX_BINARY} $count times"; 
				}
			}
		}
	}
	my $new_version;
	my $new_output = `$path_to_binary --version 2>/dev/null`;
	if ($entry =~ /^waterfox/smx) {
		$new_version = $new_output;
	} elsif ($new_output =~ /^Mozilla[ ]Firefox[ ]([\d.]+)/smx) {
		($new_version) = ($1);
	} else {
		die "$path_to_binary new '$new_output' could not be parsed";
	}
	if ($entry eq 'firefox-nightly') {
	} elsif ($entry eq 'firefox-developer') {
	} elsif ($entry eq 'firefox-upgrade') {
	} elsif ($entry eq 'waterfox') {
	} elsif ($old_version ne $new_version) {
		die "$old_version changed to $new_version for $path_to_binary";
	}
}
while (kill 0, $pid) {
	kill 'TERM', $pid;
	waitpid $pid, POSIX::WNOHANG();
}
undef $pid;
chdir $cwd or die "Failed to chdir to '$cwd':$!";
system { 'cover' } 'cover' and die "Failed to 'cover' for $ENV{FIREFOX_BINARY}";

END {
	if (defined $pid) {
		while (kill 0, $pid) {
			kill 'TERM', $pid;
			waitpid $pid, POSIX::WNOHANG();
		}
	}
}
