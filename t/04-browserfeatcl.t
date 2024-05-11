#! /usr/bin/perl -w

use strict;
use Firefox::Marionette();
use Test::More;
use File::Spec();
use MIME::Base64();
use Socket();
use Config;
use Crypt::URandom();
use lib qw(t/);

$SIG{INT} = sub { die "Caught an INT signal"; };
$SIG{TERM} = sub { die "Caught a TERM signal"; };

my $min_stealth_version = 59;
my $min_execute_script_with_null_args_version = 45;

SKIP: {
	if (!$ENV{RELEASE_TESTING}) {
                plan skip_all => "Author tests not required for installation";
	}
	if ($^O eq 'MSWin32') {
		plan skip_all => "Cannot test in a $^O environment";
	} else {
		delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
		if (defined $ENV{PATH}) {
			$ENV{PATH} = '/usr/local/sbin:/usr/sbin:/usr/local/bin:/usr/bin:/bin';
			if ($^O eq 'netbsd') {
				$ENV{PATH} .= ":/usr/pkg/sbin:/usr/pkg/bin";
			}
		}
	}
	require test_daemons;
	if (!Test::Daemon::Nginx->available()) {
		plan skip_all => "nginx does not appear to be available";
	}
	if ((Firefox::Marionette::BCD_PATH()) && (-f Firefox::Marionette::BCD_PATH())) {
	} else {
		plan skip_all => "BCD does not appear to be available.  Please run build-bcd-for-firefox.";
	}
	my $nginx_listen = '127.0.0.1';
	my $htdocs = File::Spec->catdir(Cwd::cwd(), 'browserfeatcl');
	my $nginx = Test::Daemon::Nginx->new(listen => $nginx_listen, htdocs => $htdocs, index => 'index.html');
	ok($nginx, "Started nginx Server on $nginx_listen on port " . $nginx->port() . ", with pid " . $nginx->pid());
	$nginx->wait_until_port_open();
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my %extra_parameters;
	if ($ENV{FIREFOX_BINARY}) {
		$extra_parameters{binary} = $ENV{FIREFOX_BINARY};
	}
	my $firefox = Firefox::Marionette->new(
			%extra_parameters,
			debug => $debug,
			visible => $visible,
					);
	ok($firefox, "Created a normal firefox object");
	my ($major_version, $minor_version, $patch_version) = split /[.]/smx, $firefox->browser_version();
	my $original_agent = $firefox->agent();
	ok($firefox->script('return navigator.webdriver') == JSON::true(), "\$firefox->script('return navigator.webdriver') returns true");
	my $webdriver_definition_script = 'let descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(navigator), "webdriver"); return descriptor.get.toString();';
	my $original_webdriver_definition = $firefox->script($webdriver_definition_script);
	my $quoted_webdriver_definition = $original_webdriver_definition;
	$quoted_webdriver_definition =~ s/\n/\\n/smxg;
	my $webdriver_def_regex = qr/function[ ]webdriver[(][)][ ][{]\n[ ]+\[native[ ]code\]\n[}]/smx;
	ok($original_webdriver_definition =~ /^$webdriver_def_regex$/smx, "Webdriver definition matches regex:$quoted_webdriver_definition");
	ok($firefox->quit() == 0, "\$firefox->quit() succeeded");
	$firefox = Firefox::Marionette->new(
			%extra_parameters,
			debug => $debug,
			visible => $visible,
			stealth => 1,
			devtools => 1,
					);
	ok($firefox, "Created a stealth firefox object");
	# checking against
	# https://browserleaks.com/javascript
	# https://www.amiunique.org/fingerprint
	# https://bot.sannysoft.com/
	my $freebsd_118_user_agent_string = 'Mozilla/5.0 (X11; FreeBSD amd64; rv:109.0) Gecko/20100101 Firefox/118.0';
	my %user_agents_to_js = (
		'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36' =>
						{
							platform => 'Win32',
							appVersion => '5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
							productSub => '20030107',
							vendor => 'Google Inc.',
							vendorSub => '',
							oscpu => undef,
						},
		'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0' =>
						{
							platform => 'Win32',
							appVersion => '5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0',
							productSub => '20030107',
							vendor => 'Google Inc.',
							vendorSub => '',
							oscpu => undef,
						},
		'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 OPR/109.0.0.0',
						{
							platform => 'Linux x86_64',
							appVersion => '5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 OPR/109.0.0.0',
							productSub => '20030107',
							vendor => 'Google Inc.',
							vendorSub => '',
							oscpu => undef,
						},
		'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15' =>
						{
							platform => 'MacIntel',
							appVersion => '5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15',
							productSub => '20030107',
							vendor => 'Apple Computer, Inc.',
							vendorSub => '',
							oscpu => undef,
						},
		'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:109.0) Gecko/20100101 Firefox/115.0' =>
						{
							platform => 'MacIntel',
							appVersion => '5.0 (Macintosh)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'Intel Mac OS X 10.13',
						},
		'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0' =>
						{
							platform => 'Win32',
							appVersion => '5.0 (Windows)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'Win32',
						},
		'Mozilla/5.0 (X11; OpenBSD amd64; rv:109.0) Gecko/20100101 Firefox/109.0' =>
						{
							platform => 'OpenBSD amd64',
							appVersion => '5.0 (X11)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'OpenBSD amd64',
						},
		'Mozilla/5.0 (X11; NetBSD amd64; rv:120.0) Gecko/20100101 Firefox/120.0' =>
						{
							platform => 'NetBSD amd64',
							appVersion => '5.0 (X11)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'NetBSD amd64',
						},
		'Mozilla/5.0 (X11; Linux s390x; rv:109.0) Gecko/20100101 Firefox/115.0' =>
						{
							platform => 'Linux s390x',
							appVersion => '5.0 (X11)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'Linux s390x',
						},
		'Mozilla/5.0 (X11; DragonFly x86_64; rv:108.0) Gecko/20100101 Firefox/108.0' =>
						{
							platform => 'DragonFly x86_64',
							appVersion => '5.0 (X11)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'DragonFly x86_64',
						},
		$freebsd_118_user_agent_string =>
						{
							platform => 'FreeBSD amd64',
							appVersion => '5.0 (X11)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'FreeBSD amd64',
						},
		'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0' =>
						{
							platform => 'Win32',
							appVersion => '5.0 (Windows)',
							productSub => '20100101',
							vendor => '',
							vendorSub => '',
							oscpu => 'Win32',
						},
		'Mozilla/5.0 (iPhone; CPU iPhone OS 16_7_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
						{
							platform => 'iPhone',
							appVersion => '5.0 (iPhone; CPU iPhone OS 16_7_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
							productSub => '20030107',
							vendor => 'Apple Computer, Inc.',
							vendorSub => '',
							oscpu => undef,
						},
		'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
						{
							platform => 'Linux armv81',
							appVersion => '5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
							productSub => '20030107',
							vendor => 'Google Inc.',
							vendorSub => '',
							oscpu => undef,
						},
		'Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko',
						{
							platform => 'Win32',
							appVersion => '5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko',
							productSub => undef,
							vendor => '',
							vendorSub => undef,
							oscpu => undef,
						},
		'libwww-perl/6.72' => { },
			);
	foreach my $user_agent (sort { $a cmp $b } keys %user_agents_to_js) {
		if (($major_version < $min_execute_script_with_null_args_version) && (exists $user_agents_to_js{$user_agent}{oscpu}) && (!defined $user_agents_to_js{$user_agent}{oscpu})) {
			diag("Skipping '$user_agent' as oscpu will be null and executeScript cannot handle null arguments for older firefoxen");
			next;
		}
		ok($user_agent, "Testing '$user_agent'");
		ok($firefox->agent($user_agent), "\$firefox->agent(\"$user_agent\") succeeded");
		if ($major_version > $min_stealth_version) {
			_check_navigator_attributes($firefox, $major_version, $user_agent, %user_agents_to_js);
		}
		ok($firefox->go("about:blank"), "\$firefox->go(\"about:blank\") loaded successfully for user agent test of values");
		_check_navigator_attributes($firefox, $major_version, $user_agent, %user_agents_to_js);
	}
	if ($major_version > $min_stealth_version) {
		my $agent = $firefox->agent(undef);
		ok($agent,
				"\$firefox->agent(undef)                          should return 'libwww-perl/6.72'");
		ok($agent eq 'libwww-perl/6.72',
				"\$firefox->agent(undef)                             did return '$agent'");
		$firefox->set_javascript(0);
		ok(!$firefox->get_pref('javascript.enabled'), "Javascript is disabled for $agent");
		$firefox->set_javascript(undef);
		ok($firefox->get_pref('javascript.enabled'), "Javascript is enabled for $agent");
		$firefox->set_javascript(0);
		ok(!$firefox->get_pref('javascript.enabled'), "Javascript is disabled for $agent");
		$firefox->set_javascript(1);
		ok($firefox->get_pref('javascript.enabled'), "Javascript is enabled for $agent");
		$agent = $firefox->agent(version => 120);
		ok($agent eq $original_agent,
				"\$firefox->agent(version => 120)                 should return '$original_agent'");
		ok($agent eq $original_agent,
				"\$firefox->agent(version => 120)                    did return '$agent'");
		$agent = $firefox->agent(increment => -5);
		my $correct_agent = $original_agent;
		$correct_agent =~ s/rv:\d+/rv:120/smx;
		$correct_agent =~ s/Firefox\/\d+/Firefox\/120/smx;
		ok($correct_agent,
				"\$firefox->agent(increment => -5)                should return '$correct_agent'");
		ok($agent eq $correct_agent,
				"\$firefox->agent(increment => -5)                   did return '$agent'");
		$agent = $firefox->agent(version => 108);
		$correct_agent = $original_agent;
		my $increment_major_version = $major_version - 5;
		my $increment_rv_version = $increment_major_version < 120 && $increment_major_version > 109 ? 109 : $increment_major_version;
		$correct_agent =~ s/rv:\d+/rv:$increment_rv_version/smx;
		$correct_agent =~ s/Firefox\/\d+/Firefox\/$increment_major_version/smx;
		ok($agent,
				"\$firefox->agent(version => 108)                 should return '$correct_agent'");
		ok($agent eq $correct_agent,
				"\$firefox->agent(version => 108)                    did return '$agent'");
		$agent = $firefox->agent(undef);
		$correct_agent = $original_agent;
		$correct_agent =~ s/rv:\d+/rv:108/smx;
		$correct_agent =~ s/Firefox\/\d+/Firefox\/108/smx;
		ok($agent,
				"\$firefox->agent(undef)                          should return '$correct_agent'");
		ok($agent eq $correct_agent,
				"\$firefox->agent(undef)                             did return '$agent'");
		$firefox->agent(os => 'Win64');
		$agent = $firefox->agent(undef);
		ok($agent =~ /^Mozilla\/5[.]0[ ][(]Windows[ ]NT[ ]10[.]0;[ ]Win64;[ ]x64;[ ]rv:\d{2,3}[.]0[)][ ]Gecko\/20100101[ ]Firefox\/\d{2,3}[.]0$/smx,
				"\$firefox->agent(os => 'Win64')                     did return '$agent'");
		$firefox->agent(os => 'FreeBSD', version => 110);
		$agent = $firefox->agent(undef);
		ok($agent =~ /^Mozilla\/5[.]0[ ][(]X11;[ ]FreeBSD[ ]amd64;[ ]rv:109.0[)][ ]Gecko\/20100101[ ]Firefox\/110.0$/smx,
				"\$firefox->agent(os => 'FreeBSD', version => 110)   did return '$agent'");
		$firefox->agent(os => 'linux', arch => 'i686');
		$agent = $firefox->agent(undef);
		ok($agent =~ /^Mozilla\/5[.]0[ ][(]X11;[ ]Linux[ ]i686;[ ]rv:\d{2,3}.0[)][ ]Gecko\/20100101[ ]Firefox\/\d{2,3}.0$/smx,
				"\$firefox->agent(os => 'linux', arch => 'i686')     did return '$agent'");
		$firefox->agent(os => 'darwin');
		$agent = $firefox->agent(undef);
		ok($agent =~ /^Mozilla\/5[.]0[ ][(]Macintosh;[ ]Intel[ ]Mac[ ]OS[ ]X[ ]\d+[.]\d+;[ ]rv:\d{2,3}.0[)][ ]Gecko\/20100101[ ]Firefox\/\d{2,3}.0$/smx,
				"\$firefox->agent(os => 'darwin')                    did return '$agent'");
		$firefox->agent(os => 'darwin', platform => 'X11');
		$agent = $firefox->agent(undef);
		ok($agent =~ /^Mozilla\/5[.]0[ ][(]X11;[ ]Intel[ ]Mac[ ]OS[ ]X[ ]\d+[.]\d+;[ ]rv:\d{2,3}.0[)][ ]Gecko\/20100101[ ]Firefox\/\d{2,3}.0$/smx,
				"\$firefox->agent(os => 'darwin', platform => 'X11') did return '$agent'");
		$firefox->agent(os => 'darwin', arch => '10.13');
		$agent = $firefox->agent(undef);
		ok($agent =~ /^Mozilla\/5[.]0[ ][(]Macintosh;[ ]Intel[ ]Mac[ ]OS[ ]X[ ]10[.]13;[ ]rv:\d{2,3}.0[)][ ]Gecko\/20100101[ ]Firefox\/\d{2,3}.0$/smx,
				"\$firefox->agent(os => 'darwin', arch => '10.13')   did return '$agent'");
		$firefox->agent(os => 'freebsd', version => 118);
		$agent = $firefox->agent(undef);
		ok($agent eq $freebsd_118_user_agent_string,
				"\$firefox->agent(os => 'freebsd', version => '118') did return '$agent'");
		eval { $firefox->agent(version => 'blah') };
		my $exception = $@;
		chomp $exception;
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->agent(version => 'blah') throws an exception:$exception");
		eval { $firefox->agent(increment => 'blah') };
		$exception = $@;
		chomp $exception;
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->agent(increment => 'blah') throws an exception:$exception");
	}
	check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
	{
		my $tmp_dir = File::Temp->newdir(
					TEMPLATE => File::Spec->catdir(File::Spec->tmpdir(), 'perl_ff_m_test_XXXXXXXXXXX')
						) or die "Failed to create temporary directory:$!";
		local $ENV{HOME} = $tmp_dir->dirname();;
		my $bcd_path = Firefox::Marionette::BCD_PATH(1);
		ok($bcd_path, "Created $bcd_path for BCD file in $bcd_path");
		ok(1, "About to go to Firefox v122 with no BCD file available in $ENV{HOME}");
		ok($firefox->agent(version => 122), "\$firefox->agent(version => 122) with no BCD file available, but BCD_PATH(1) called");
		ok($firefox->agent(undef), "\$firefox->agent(undef) to reset agent string to original");
	}
	{
		my $tmp_dir = File::Temp->newdir(
					TEMPLATE => File::Spec->catdir(File::Spec->tmpdir(), 'perl_ff_m_test_XXXXXXXXXXX')
						) or die "Failed to create temporary directory:$!";
		local $ENV{HOME} = $tmp_dir->dirname();;
		ok(1, "About to go to Firefox v122 with no BCD file available in $ENV{HOME}");
		ok($firefox->agent(version => 122), "\$firefox->agent(version => 122) with no BCD file available and BCD_PATH(1) not called");
		ok($firefox->agent(undef), "\$firefox->agent(undef) to reset agent string to original");
	}
	{
		my %agent_parameters = (
					from => 'Mozilla/5.0 (X11; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/125.0',
					to => 'Mozilla/5.0 (X11; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/100.0',
					filters => qr/(?:ContentVisibilityAutoStateChangeEvent|withResolvers)/smxi
				);
		my $javascript = Firefox::Marionette::Extension::Stealth->user_agent_contents(%agent_parameters);
		ok($javascript =~ /delete[ ]window[.]ContentVisibilityAutoStateChangeEvent/, "Filtered extension code includes ContentVisibilityAutoStateChangeEvent");
		ok($javascript !~ /delete[ ]window[.]ShadowRoot/, "Filtered extension code does NOT include ShadowRoot");
		my $from = $agent_parameters{from};
		my $to = $agent_parameters{to};
		$agent_parameters{from} = $to;
		$agent_parameters{to} = $from;
		$javascript = Firefox::Marionette::Extension::Stealth->user_agent_contents(%agent_parameters);
		ok($javascript =~ /Object.defineProperty[(]window[.]ContentVisibilityAutoStateChangeEvent/, "Filtered extension code includes ContentVisibilityAutoStateChangeEvent");
		ok($javascript !~ /Object.defineProperty[(]window[.]ShadowRoot/, "Filtered extension code does NOT include ShadowRoot");
		$agent_parameters{from} = $from;
		$agent_parameters{to} = $to;
		delete $agent_parameters{filters};
		$javascript = Firefox::Marionette::Extension::Stealth->user_agent_contents(%agent_parameters);
		ok($javascript =~ /delete[ ]window[.]ContentVisibilityAutoStateChangeEvent/, "Extension code includes ContentVisibilityAutoStateChangeEvent");
		ok($javascript =~ /delete[ ]window[.]ShadowRoot/, "Extension code includes ShadowRoot");
	}
	foreach my $version (reverse (6 .. 124)) {
		ok(1, "About to go to Firefox v$version");
		my $agent = $firefox->agent(version => $version);
		ok($agent =~ /Firefox\/(\d+)/smx, "\$firefox->agent(version => $version) produces the actual agent string which contains Firefox version '$1'");
		check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
		ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Loaded browserfeatcl");
		$agent = $firefox->agent();
		ok($agent =~ /Firefox\/(\d+)/smx, "\$firefox->agent() contains Firefox version '$1' in the agent string (real version is " . $firefox->browser_version() . ")");
		my $test_result_version = $1;
		my $extracted_report = $firefox->await(sub { $firefox->has_class('success') or $firefox->has_class('error') })->text();
		ok($extracted_report =~ /You[']re[ ]using[ ]Firefox[ ](\d+)(?:[.]\d+)?(?:[ ]\-[ ](\d+)(?:[.]9)?[!])?/smx, "browserfeatcl reports '$extracted_report' which matches Firefox");
		my ($min_version, $max_version) = ($1, $2);
		if (defined $max_version) {
			ok($min_version <= $version && $version <= $max_version, "browserfeatcl matches between $min_version and $max_version which includes fake version '$version'");
		} else {
			ok($min_version == $version, "browserfeatcl matches $min_version which equals fake version '$version'");
		}
		check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
		ok($firefox->agent(undef), "\$firefox->agent(undef) to reset agent string to original");
	}
	foreach my $version (reverse (80 .. 121)) {
		my $chrome_user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$version.0.0.0 Safari/537.36";
		ok(1, "About to go to Chrome v$version - $chrome_user_agent");
		my $agent = $firefox->agent($chrome_user_agent);
		ok($agent =~ /Firefox\/(\d+)/smx, "\$firefox->agent('$chrome_user_agent') produces the actual agent string which contains Firefox version '$1'");
		check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
		ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Loaded browserfeatcl");
		$agent = $firefox->agent();
		ok($agent =~ /Chrome\/$version/smx, "\$firefox->agent() contains Chrome version '$version' in the agent string (real version is Firefox v" . $firefox->browser_version() . ")");
		my $extracted_report = $firefox->await(sub { $firefox->has_class('success') or $firefox->has_class('error') })->text();
		ok($extracted_report =~ /You[']re[ ]using[ ]Chrom(?:e|ium)[ ](\d+)(?:[.]\d+)?(?:[ ]\-[ ](\d+)[!])?/smx, "browserfeatcl reports '$extracted_report' which matches Chrome");
		my ($min_version, $max_version) = ($1, $2);
		if (defined $max_version) {
			ok($min_version <= $version && $version <= $max_version, "browserfeatcl matches between $min_version and $max_version which includes fake version '$version'");
		} else {
			ok($min_version == $version, "browserfeatcl matches $min_version which equals fake version '$version'");
		}
		check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
		ok($firefox->agent(undef), "\$firefox->agent(undef) to reset agent string to original");
	}
	foreach my $version (reverse (9 .. 17)) {
		my $safari_user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$version Safari/605.1.15";
		ok(1, "About to go to Safari v$version - $safari_user_agent");
		my $agent = $firefox->agent($safari_user_agent);
		ok($agent =~ /Firefox\/(\d+)/smx, "\$firefox->agent('$safari_user_agent') produces the actual agent string which contains Firefox version '$1'");
		check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
		ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Loaded browserfeatcl");
		$agent = $firefox->agent();
		ok($agent =~ /Version\/$version[ ]Safari\/(\d+)/smx, "\$firefox->agent() contains Safari version '$version' in the agent string (real version is Firefox v" . $firefox->browser_version() . ")");
		my $extracted_report = $firefox->await(sub { $firefox->has_class('success') or $firefox->has_class('error') })->text();
		ok($extracted_report =~ /You[']re[ ]using[ ]Safari[ ](\d+)(?:[.]\d+)?(?:[ ]\-[ ](\d+)[.]9[!])?/smx, "browserfeatcl reports '$extracted_report' which matches Safari");
		my ($min_version, $max_version) = ($1, $2);
		if (defined $max_version) {
			ok($min_version <= $version && $version <= $max_version, "browserfeatcl matches between $min_version and $max_version which includes fake version '$version'");
		} else {
			ok($min_version == $version, "browserfeatcl matches $min_version which equals fake version '$version'");
		}
		check_webdriver($firefox, $webdriver_definition_script, $webdriver_def_regex);
		ok($firefox->agent(undef), "\$firefox->agent(undef) to reset agent string to original");
	}
	ok($firefox->quit() == 0, "\$firefox->quit() was successful()");
	ok($nginx->stop() == 0, "Stopped nginx on $nginx_listen:" . $nginx->port());
}

sub check_webdriver {
	my ($firefox, $webdriver_definition_script, $webdriver_def_regex) = @_;
	if ($firefox->script(q[if ('webdriver' in navigator) { return 1 } else { return 0 }])) {
		ok($firefox->script('return navigator.webdriver') == JSON::false(), "\$firefox->script('return navigator.webdriver') returns false");
		my $stealth_webdriver_definition = $firefox->script($webdriver_definition_script);
		my $quoted_webdriver_definition = $stealth_webdriver_definition;
		$quoted_webdriver_definition =~ s/\n/\\n/smxg;
		ok($stealth_webdriver_definition =~ /^$webdriver_def_regex$/smx, "Webdriver definition matches:$quoted_webdriver_definition");
	} else {
		my $agent = $firefox->agent();
		ok(1, "Webdriver does not exist for " . $agent);
	}
	return;
}

sub _check_navigator_attributes {
	my ($firefox, $major_version, $user_agent, %user_agents_to_js) = @_;
	my $count = 0;
	KEY: foreach my $key (qw(
				platform
				appVersion
			)) {
		my $value = $firefox->script('return navigator.' . $key);
		if ($user_agent =~ /^libwww[-]perl/smx) {
			ok(defined $value, "navigator.$key is unchanged as '$value'");
		} elsif (defined $user_agents_to_js{$user_agent}{$key}) {
			if (($value ne $user_agents_to_js{$user_agent}{$key}) && ($major_version < 62) && ($major_version > 59) && ($count <= 1)) { # firefox-60.0esr has blown up on this b/c of a seeming race condition
				my $redo_seconds = 4;
				$count += 1;
				diag("The navigator.$key value is incorrect as '$value'.  Waiting $redo_seconds seconds to try again");
				sleep $redo_seconds;
				redo KEY;
			}
			ok($value eq $user_agents_to_js{$user_agent}{$key}, "navigator.$key is now '$user_agents_to_js{$user_agent}{$key}':$value");
		} else {
			ok(!defined $value, "navigator.$key is undefined");
		}
	}
	if ($major_version > $min_stealth_version) {
		$count = 0;
		KEY2: foreach my $key (qw(
					productSub
					vendor
					vendorSub
					oscpu
				)) {
			my $value = $firefox->script('return navigator.' . $key);
			if ($user_agent =~ /^libwww[-]perl/smx) {
				ok(defined $value, "navigator.$key is unchanged as '$value'");
			} elsif (defined $user_agents_to_js{$user_agent}{$key}) {
				if (($value ne $user_agents_to_js{$user_agent}{$key}) && ($major_version < 62) && ($major_version > 59) && ($count <= 1)) { # firefox-60.0esr has blown up on this b/c of a seeming race condition
					my $redo_seconds = 4;
					$count += 1;
					diag("The navigator.$key value is incorrect as '$value'.  Waiting $redo_seconds seconds to try again");
					sleep $redo_seconds;
					redo KEY2;
				}
				ok($value eq $user_agents_to_js{$user_agent}{$key}, "navigator.$key is now '$user_agents_to_js{$user_agent}{$key}':$value");
			} else {
				ok(!defined $value, "navigator.$key is undefined");
			}
		}
	}
	my $value = $firefox->script('return navigator.userAgent');
	ok($user_agent eq $value, "navigator.userAgent is now '$user_agent':$value");
}

done_testing();
