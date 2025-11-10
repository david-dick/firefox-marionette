#! /usr/bin/perl

use strict;
use warnings;
use Digest::SHA();
use MIME::Base64();
use Test::More;
use Cwd();
use Encode();
use Firefox::Marionette();
use Waterfox::Marionette();
use Compress::Zlib();
use IO::Socket::IP();
use Config;
use HTTP::Daemon();
use HTTP::Status();
use HTTP::Response();
use IO::Socket::SSL();
use File::HomeDir();
BEGIN: {
    if ( $^O eq 'MSWin32' ) {
        require Win32::Process;
    }
}

my $segv_detected;
my $at_least_one_success;
my $terminated;
my $class;
my $arch_32bit_re = qr/^(?:x86|arm(?:hf|el)?)$/smxi;
my $quoted_home_directory = quotemeta File::HomeDir->my_home();
my $is_covering = !!(eval 'Devel::Cover::get_coverage()');

my $oldfh = select STDOUT; $| = 1; select $oldfh;
$oldfh = select STDERR; $| = 1; select $oldfh;

if (defined $ENV{WATERFOX}) {
	$class = 'Waterfox::Marionette';
	$class->import(qw(:all));
} else {
	$class = 'Firefox::Marionette';
	$class->import(qw(:all));
}
diag("Starting test at " . localtime);
my $alarm;
if (defined $ENV{FIREFOX_ALARM}) {
	if ($ENV{FIREFOX_ALARM} =~ /^(\d{1,6})\s*$/smx) {
		($alarm) = ($1);
		diag("Setting the ALARM value to $alarm");
		alarm $alarm;
	} else {
		die "Invalid value of FIREFOX_ALARM ($ENV{FIREFOX_ALARM})";
	}
}
foreach my $name (qw(FIREFOX_HOST FIREFOX_USER)) {
	if (exists $ENV{$name}) {
		if (defined $ENV{$name}) {
			$ENV{$name} =~ s/\s*$//smx;
		} else {
			die "This is just not possible:$name";
		}
	}
}

my $test_time_limit = 90;
my $page_content = 'page-content';
my $form_control = 'form-control';
my $css_form_control = 'input.form-control';
my $footer_links = 'footer-links';
my $xpath_for_read_text_and_size = '//a[@class="keyboard-shortcuts"]';
my $freeipapi_uri = 'data:application/json,{"ipVersion":6,"ipAddress":"2001:8001:4ab3:d800:7215:c1fe:fc85:1329","latitude":-37.5,"longitude":144.5,"countryName":"Australia","countryCode":"AU","timeZone":"+11:00","zipCode":"3000","cityName":"Melbourne","regionName":"Victoria","isProxy":false,"continent":"Oceania","continentCode":"OC"}'; # sourced from https://freeipapi.com/api/json/
my $geocode_maps_uri = 'data:application/json,[{"place_id":18637666,"licence":"Data © OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright","osm_type":"node","osm_id":6173167285,"boundingbox":["-37.6","-37.4","144.4","144.5"],"lat":"-37.5","lon":"144.5","display_name":"Boston Consulting Group, 101, Collins Street, East End Theatre District, Melbourne, City of Melbourne, Victoria, 3000, Australia","class":"office","type":"company","importance":1.1674899222535406}]'; # sourced from https://geocode.maps.co/search?street=101+Collins+St&city=Melbourne&state=VIC&postalcode=3000&country=AU&format=json
my $positionstack_uri = 'data:application/json,{"data":[{"latitude":-37.5,"longitude":144.5,"type":"address","name":"101 Collins Street","number":"101","postal_code":"3000","street":"Collins Street","confidence":1,"region":"Victoria","region_code":"VIC","county":"Melbourne","locality":"Melbourne","administrative_area":"Melbourne","neighbourhood":null,"country":"Australia","country_code":"AUS","continent":"Oceania","label":"101 Collins Street, Melbourne, VIC, Australia"}]}'; # source from http://api.positionstack.com/v1/forward?access_key=$API_KEY_HERE&query=101+Collins+St,Melbourne,VIC+3000
my $ipgeolocation_uri = 'data:application/json,{"ip":"2001:8001:4ab3:d800:7215:c1fe:fc85:1329","continent_code":"OC","continent_name":"Oceania","country_code2":"AU","country_code3":"AUS","country_name":"Australia","country_name_official":"Commonwealth of Australia","country_capital":"Canberra","state_prov":"Victoria","state_code":"AU-VIC","district":"","city":"Melbourne","zipcode":"3000","latitude":"-37.5","longitude":"144.5","is_eu":false,"calling_code":"+61","country_tld":".au","languages":"en-AU","country_flag":"https://ipgeolocation.io/static/flags/au_64.png","geoname_id":"2166436","isp":"Telstra Corporation Limited","connection_type":"","organization":"Telstra Corporation Limited","currency":{"code":"AUD","name":"Australian Dollar","symbol":"A$"},"time_zone":{"name":"Australia/Melbourne","offset":10,"offset_with_dst":11,"current_time":"2024-01-09 17:54:54.413+1100","current_time_unix":1704783294.413,"is_dst":true,"dst_savings":1}}'; # sourced from https://api.ipgeolocation.io/ipgeo?apiKey=$API_KEY_HERE
my $ipstack_uri = 'data:application/json,{"ip": "2001:8003:4a03:d800:7285:c2ff:fe85:1528", "type": "ipv6", "continent_code": "OC", "continent_name": "Oceania", "country_code": "AU", "country_name": "Australia", "region_code": "VIC", "region_name": "Victoria", "city": "Melbourne", "zip": "3000", "latitude": -37.5, "longitude": 144.5, "location": {"geoname_id": 2158177, "capital": "Canberra", "languages": [{"code": "en", "name": "English", "native": "English"}], "country_flag": "https://assets.ipstack.com/flags/au.svg", "country_flag_emoji": "\ud83c\udde6\ud83c\uddfa", "country_flag_emoji_unicode": "U+1F1E6 U+1F1FA", "calling_code": "61", "is_eu": false}}';
my $dummy1_uri = 'data:application/json,{"latitude":40.7,"longitude":-73.9,"time_zone":{"current_time":"2024-01-09 04:36:29.524-0500"}}'; # dummy data for testing (roughly new york)
my $dummy2_uri = 'data:application/json,{"latitude":40.7,"longitude":-73.9,"time_zone":{"current_time":"1234abc"}}'; # dummy data for testing bad data
my $most_common_useragent = q[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36];
my $useragents_me_uri = qq[data:application/json,{"about": "Use this API to get a list of current popular useragents. Please post a link back to the site if you find it useful!", "terms": "As the data here don't change sooner than once per week, you shouldn't need to make lots of requests all at once. Currently, we impose a rate-limit of 15 requests per IP address per hour (even this is probably too many)", "data": [{"ua": "$most_common_useragent", "pct": 37.8271882916}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63", "pct": 14.2696312975}, {"ua": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36", "pct": 10.8077680833}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/110.0", "pct": 6.5859836758}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.57", "pct": 4.9535603715}, {"ua": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36", "pct": 4.5032367014}, {"ua": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15", "pct": 4.5032367014}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36", "pct": 1.9138755981}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36 OPR/95.0.0.0", "pct": 1.2383900929}, {"ua": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36", "pct": 0.7880664227}, {"ua": "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/110.0", "pct": 0.7880664227}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.41", "pct": 0.7880664227}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.56", "pct": 0.6754855052}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.53 Safari/537.36 Edg/103.0.1264.37", "pct": 0.6754855052}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:102.0) Gecko/20100101 Firefox/102.0", "pct": 0.6754855052}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.85 Safari/537.36 Edg/90.0.818.46", "pct": 0.5629045877}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.50", "pct": 0.5629045877}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Whale/3.19.166.16 Safari/537.36", "pct": 0.5629045877}, {"ua": "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/110.0", "pct": 0.4503236701}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36 Edg/108.0.1462.76", "pct": 0.4503236701}, {"ua": "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36", "pct": 0.4503236701}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.46", "pct": 0.3377427526}, {"ua": "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:109.0) Gecko/20100101 Firefox/110.0", "pct": 0.3377427526}, {"ua": "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko", "pct": 0.3377427526}, {"ua": "Mozilla/5.0 (Windows NT 6.3; Win64; x64; rv:109.0) Gecko/20100101 Firefox/110.0", "pct": 0.3377427526}, {"ua": "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36 Core/1.94.192.400 QQBrowser/11.5.5250.400", "pct": 0.3377427526}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36 Edg/109.0.1518.78", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.120 Safari/537.36", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36 OPR/95.0.0.0", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36 Edg/92.0.902.67", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:108.0) Gecko/20100101 Firefox/108.0", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.141 Safari/537.36", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/18.17763", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (X11; Linux x86_64; rv:108.0) Gecko/20100101 Firefox/108.0", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/111.0", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36 Edg/108.0.1462.54", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36 Edg/109.0.1518.61", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/110.0", "pct": 0.2251618351}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36 Edg/109.0.1518.70", "pct": 0.2251618351}], "updated": 1678066547, "thanks": "https://www.useragents.me/"}];

my $min_geo_version = 60;
my $min_stealth_version = 59;

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
       foreach my $env_name (
				'XAUTHORITY',           # see GH#1
				'XDG_RUNTIME_DIR',      # see GH#33
                         ) {
            if ( exists $ENV{$env_name} ) {
                delete $ENV{$env_name};
                warn "Running as root.  Deleting the $env_name environment variable\n";
            }
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

sub wait_for_server_on {
	my ($daemon, $url, $pid) = @_;
	my $host = URI->new($url)->host();
	my $port = URI->new($url)->port();
	undef $daemon;
	CONNECT: while (!IO::Socket::IP->new(Type => Socket::SOCK_STREAM(), PeerPort => $port, PeerHost => $host)) {
		diag("Waiting for server ($pid) to listen on $host:$port:$!");
		waitpid $pid, POSIX::WNOHANG();
		if (kill 0, $pid) {
			sleep 1;
		} else {
			diag("Server ($pid) has exited");
			last CONNECT;
		}
	}
	return 
}

sub empty_port {
	socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0 or die "Failed to create a socket:$!";
	bind $socket, Socket::sockaddr_in( 0, Socket::INADDR_LOOPBACK() ) or die "Failed to bind socket:$!";
	my $port = ( Socket::sockaddr_in( getsockname $socket ) )[0];
	close $socket or die "Failed to close random socket:$!";
	return $port;
}

sub process_alive {
	my ($pid) = @_;
	if ($^O eq 'MSWin32') {
		if (Win32::Process::Open(my $process, $pid, 0)) {
			$process->GetExitCode( my $exit_code );
			if ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
				return 1;
			}
		} else {
			return 0;
		}
	} else {
		return kill 0, $pid;
	}
}

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
my $ca_private_key_handle;
my $metacpan_ca_cert_handle;
my $guid_regex = qr/[a-f\d]{8}\-[a-f\d]{4}\-[a-f\d]{4}\-[a-f\d]{4}\-[a-f\d]{12}/smx;
my @old_binary_keys = (qw(firefox_binary firefox marionette));;

my ($major_version, $minor_version, $patch_version); 
sub start_firefox {
	my ($require_visible, %parameters) = @_;
	if ($terminated) {
		die "Caught a signal";
	}
	if ($ENV{FIREFOX_BINARY}) {
		my $key = shift @old_binary_keys;
		$key ||= 'binary';
		$parameters{$key} = $ENV{FIREFOX_BINARY};
		diag("Overriding firefox binary to $parameters{$key}");
	}
	if ($ENV{FIREFOX_FORCE_SCP}) {
		$parameters{scp} = 1;
	}
	if ($parameters{manual_certificate_add}) {
		delete $parameters{manual_certificate_add};
	} elsif ((defined $parameters{system_access}) && ($parameters{system_access} == 0)) {
	} elsif (defined $ca_cert_handle) {
		if ($launches % 2) {
			diag("Setting trust to list");
			$parameters{trust} = [ $ca_cert_handle->filename() ];
		} else {
			diag("Setting trust to scalar");
			$parameters{trust} = $ca_cert_handle->filename();
		}
	}
	if (defined $major_version) {
		if ($major_version >= $min_stealth_version) { # https://developer.mozilla.org/en-US/docs/Web/API/Navigator/webdriver#browser_compatibility
		} elsif ($parameters{stealth}) {
			diag("stealth support is not available for Firefox versions less than $min_stealth_version");
			delete $parameters{stealth};
		}
		if ($major_version >= $min_geo_version) {
		} elsif ($parameters{geo}) {
			diag("geo support is not available for Firefox versions less than $min_geo_version");
			delete $parameters{geo};
		}
		if ((defined $major_version) && ($major_version >= 61)) {
		} elsif ($parameters{har}) {
			diag("HAR support is not available for Firefox versions less than 61");
			delete $parameters{har};
		}
		if ((defined $major_version) && ($major_version >= 60)) {
		} elsif ($parameters{bookmarks}) {
			diag("Bookmark support is not available for Firefox versions less than 60");
			delete $parameters{bookmarks};
		}
	}
	if ($parameters{console}) {
		$parameters{console} = 1;
	}
	if (defined $ENV{WATERFOX_VIA_FIREFOX}) {
		$parameters{waterfox} = 1;
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
	my $skip_message;
	if ($ENV{FIREFOX_HOST}) {
		$parameters{host} = $ENV{FIREFOX_HOST};
		diag("Overriding host to '$parameters{host}'");
		if ($ENV{FIREFOX_VIA}) {
			$parameters{via} = $ENV{FIREFOX_VIA};
		}
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
		if (($parameters{visible}) || ($require_visible)) {
			$skip_message = "Firefox visible tests are unreliable on a remote host";
			return ($skip_message, undef);
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
		$parameters{visible} = $require_visible;
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
	} elsif ($ENV{FIREFOX_NO_VISIBLE}) {
		$parameters{visible} = 0;
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
	} else {
		$parameters{visible} = $require_visible;
	}
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
		$firefox = $class->new(%parameters);
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
				$firefox = $class->new(%parameters);
			};
			if ($firefox) {
				$segv_detected = 1;
			} else {
				diag("Caught a second exception:$@");
				$skip_message = "Skip tests that depended on firefox starting successfully:$@";
			}
		}
	} elsif ($exception =~ /^Alarm at time exceeded/) {
		die $exception;
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
		if (defined $firefox->root_directory()) {
			ok($firefox, "\$firefox->root_directory() is " . $firefox->root_directory());
		} else {
			ok($firefox, "\$firefox->root_directory() is not defined yet");
		}
	}
	return ($skip_message, $firefox);
}

umask 0;
my $binary = 'firefox';
if ($ENV{FIREFOX_BINARY}) {
	$binary = $ENV{FIREFOX_BINARY};
} elsif ( $^O eq 'MSWin32' ) {
    foreach my $possible ( 'ProgramFiles(x86)', 'ProgramFiles' ) {
        if (( $ENV{$possible} ) && (-e File::Spec->catfile($ENV{$possible}, 'Mozilla Firefox', 'firefox.exe') )) {
	    $binary = File::Spec->catfile(
		$ENV{$possible},
		'Mozilla Firefox',
		'firefox.exe'
	    );
            last;
        }
    }
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
if ($version_string =~ /^Mozilla[ ]Firefox[ ](\d+)[.](\d+)(?:a1)?(?:[.](\d+)(?:esr)?)?$/smx) {
	($major_version, $minor_version, $patch_version) = ($1, $2, $3);
}
if ((exists $ENV{FIREFOX_HOST}) && (defined $ENV{FIREFOX_HOST})) {
	diag("FIREFOX_HOST is $ENV{FIREFOX_HOST}");
}
if ((exists $ENV{FIREFOX_USER}) && (defined $ENV{FIREFOX_USER})) {
	diag("FIREFOX_USER is $ENV{FIREFOX_USER}");
}
if ((exists $ENV{FIREFOX_PORT}) && (defined $ENV{FIREFOX_PORT})) {
	diag("FIREFOX_PORT is $ENV{FIREFOX_PORT}");
}
if ((exists $ENV{FIREFOX_VIA}) && (defined $ENV{FIREFOX_VIA})) {
	diag("FIREFOX_VIA is $ENV{FIREFOX_VIA}");
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
foreach my $name (Waterfox::Marionette::Profile->names()) {
	my $profile = Waterfox::Marionette::Profile->existing($name);
	$count += 1;
}
ok(1, "Read $count existing profiles");
diag("This firefox installation has $count existing profiles");
if (Firefox::Marionette::Profile->default_name()) {
	ok(1, "Found default profile");
} else {
	ok(1, "No default profile");
}
if (Waterfox::Marionette::Profile->default_name()) {
	ok(1, "Found default waterfox profile");
} else {
	ok(1, "No default waterfox profile");
}
my $profile;
eval {
	if ($ENV{WATERFOX}) {
		$profile = Waterfox::Marionette::Profile->existing();
	} else {
		$profile = Firefox::Marionette::Profile->existing();
	}
};
ok(1, "Read existing profile if any");
my $firefox;
eval {
	$firefox = $class->new(binary => '/firefox/is/not/here');
};
chomp $@;
ok((($@) and (not($firefox))), "$class->new() threw an exception when launched with an incorrect path to a binary:$@");
eval {
	$firefox = $class->new(binary => $^X);
};
chomp $@;
ok((($@) and (not($firefox))), "$class->new() threw an exception when launched with a path to a non firefox binary:$@");
my $tls_tests_ok;
if ($ENV{RELEASE_TESTING}) {
	if ( 
		!IO::Socket::SSL->new(
		PeerAddr => 'missing.example.org:443',
		SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
			) ) {
		if ( IO::Socket::SSL->new(
		PeerAddr => 'metacpan.org:443',
		SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER(),
			) ) {
			diag("TLS/Network seem okay");
			$tls_tests_ok = 1;
		} else {
			diag("TLS/Network are NOT okay:Failed to connect to metacpan.org:$IO::Socket::SSL::SSL_ERROR");
		}
	} else {
		diag("TLS/Network are NOT okay:Successfully connected to missing.example.org");
	}
}
my $skip_message;
my $profiles_work = 1;
SKIP: {
	if ($ENV{FIREFOX_BINARY}) {
		skip("No profile testing when the FIREFOX_BINARY override is used", 6);
	}
	if (($ENV{WATERFOX}) || ($ENV{WATERFOX_VIA_FIREFOX})) {
		skip("No profile testing when any WATERFOX override is used", 6);
	}
	if ($ENV{FIREFOX_DEVELOPER}) {
		skip("No profile testing when the FIREFOX_DEVELOPER override is used", 6);
	}
	if ($ENV{FIREFOX_NIGHTLY}) {
		skip("No profile testing when the FIREFOX_NIGHTLY override is used", 6);
	}
	if (!$ENV{RELEASE_TESTING}) {
		skip("No profile testing except for RELEASE_TESTING", 6);
	}
	my @names = Firefox::Marionette::Profile->names();
	foreach my $name (@names) {
		next unless ($name eq 'throw');
		$profiles_work = 0;
		($skip_message, $firefox) = start_firefox(0, debug => 1, profile_name => $name );
		if (!$skip_message) {
			$at_least_one_success = 1;
		}
		if ($skip_message) {
			skip($skip_message, 6);
		}
		ok($firefox, "Firefox loaded with the $name profile");
		if ($major_version < 52) {
		} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		} else {
			my $install_path = Cwd::abs_path('t/addons/test.xpi');
			diag("Original install path is $install_path");
			if ($^O eq 'MSWin32') {
				$install_path =~ s/\//\\/smxg;
			}
			diag("Installing extension from $install_path");
			my $temporary = 1;
			my $install_id = $firefox->install($install_path, $temporary);
			ok($install_id, "Successfully installed an extension:$install_id");
			ok($firefox->uninstall($install_id), "Successfully uninstalled an extension");
		}
		ok($firefox->go('http://example.com'), "firefox with the $name profile loaded example.com");
		ok($firefox->quit() == 0, "firefox with the $name profile quit successfully");
		my $profile;
		if ($ENV{WATERFOX}) {
			$profile = Waterfox::Marionette::Profile->existing($name);
		} else {
			$profile = Firefox::Marionette::Profile->existing($name);
		}
		$profile->set_value('security.webauth.webauthn_enable_softtoken', 'true', 0);
		($skip_message, $firefox) = start_firefox(0, profile => $profile );
		if (defined $ENV{FIREFOX_DEBUG}) {
			ok($firefox->debug() eq $ENV{FIREFOX_DEBUG}, "\$firefox->debug() returns \$ENV{FIREFOX_DEBUG}:$ENV{FIREFOX_DEBUG}");
		} else {
			ok(!$firefox->debug(1), "\$firefox->debug(1) returns false but sets debug to true");
			ok($firefox->debug(), "\$firefox->debug() returns true");
		}
		ok($firefox, "Firefox loaded with a profile copied from $name");
		ok($firefox->go('http://example.com'), "firefox with the copied profile from $name loaded example.com");
		ok($firefox->quit() == 0, "firefox with the profile copied from $name quit successfully");
		$profiles_work = 1;
	}
}
if ($ENV{WATERFOX}) {
	ok($profile = Waterfox::Marionette::Profile->new(), "Waterfox::Marionette::Profile->new() correctly returns a new profile");
} else {
	ok($profile = Firefox::Marionette::Profile->new(), "Firefox::Marionette::Profile->new() correctly returns a new profile");
}
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
if ($ENV{FIREFOX_BINARY}) {
	$profile->set_value('security.sandbox.content.level', 0, 0); # https://wiki.mozilla.org/Security/Sandbox#Customization_Settings
}
my $correct_exit_status = 0;
my $mozilla_pid_support;
my $original_agent;
my $uname;
my $arch;
my $nightly;
my $developer;
SKIP: {
	diag("Initial tests");
	($skip_message, $firefox) = start_firefox(0, debug => 1, profile => $profile, mime_types => [ 'application/pkcs10', 'application/pdf' ]);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 38);
	}
        if (defined $ENV{FIREFOX_DEBUG}) {
		ok($firefox->debug() eq $ENV{FIREFOX_DEBUG}, "\$firefox->debug() returns \$ENV{FIREFOX_DEBUG}:$ENV{FIREFOX_DEBUG}");
	} else {
		ok($firefox->debug(), "\$firefox->debug() returns true");
	}
	ok($firefox, "Firefox has started in Marionette mode");
	ok((scalar grep { /^application\/pkcs10$/ } $firefox->mime_types()), "application/pkcs10 has been added to mime_types");
	ok((scalar grep { /^application\/pdf$/ } $firefox->mime_types()), "application/pdf was already in mime_types");
	ok((scalar grep { /^application\/x\-gzip$/ } $firefox->mime_types()), "application/x-gzip was already in mime_types");
	ok((!scalar grep { /^text\/html$/ } $firefox->mime_types()), "text/html should not be in mime_types");
	my $capabilities = $firefox->capabilities();
	ok(1, "\$capabilities->proxy() " . defined $capabilities->proxy() ? "shows an existing proxy setup" : "is undefined");
	$original_agent = $firefox->agent();
	$uname = $firefox->uname();
	$arch = $firefox->arch();
	diag("Browser version is " . $capabilities->browser_version());
	if ($firefox->nightly()) {
		$nightly = 1;
		diag($capabilities->browser_version() . " is a nightly release");
	}
	if ($firefox->developer()) {
		$developer = 1;
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
	diag("User Agent is $original_agent");
	diag("uname is $uname");
	diag("Arch is $arch");
	ok($uname, "Firefox is currently running in $uname");
	ok($arch, "Firefox is currently running on $arch");
	if ($major_version > 50) {
		ok($capabilities->platform_version(), "Firefox Platform version is " . $capabilities->platform_version());
	}
	if (($^O eq 'MSWin32') || ($^O eq 'cygwin') || ($^O eq 'darwin') || ($ENV{FIREFOX_NO_UPDATE})) {
		if ($ENV{FIREFOX_HOST}) {
			diag("No update checks for $ENV{FIREFOX_HOST}");
		} else {
			diag("No update checks for $^O");
		}
	} elsif (($ENV{RELEASE_TESTING}) && ($major_version >= 52)) {
		my $update = $firefox->update();
		ok(ref $update eq 'Firefox::Marionette::UpdateStatus', "\$firefox->update() produces a Firefox::Marionette::UpdateStatus object");
		diag("Update status code is " . $update->update_status_code());
		if ($update->successful()) {
			while ($update->successful()) {
				ok(1, "Firefox was updated");
				my $capabilities = $firefox->capabilities();
				diag("Firefox BuildID is " . ($capabilities->moz_build_id() || 'Unknown') . " after an update");
				foreach my $key (qw(app_version build_id channel details_url display_version elevation_failure error_code install_date is_complete_update name number_of_updates patch_count previous_app_version prompt_wait_time selected_patch service_url status_text type unsupported update_state update_status_code)) {
					if (defined $update->$key()) {
						if ($key =~ /^(elevation_failure|unsupported|is_complete_update)$/smx) {
							ok((($update->$key() == 1) || ($update->$key() == 0)), "\$update->$key() produces a boolean:" . $update->$key());
						} elsif ($key eq 'type') {
							ok($update->$key() =~ /^(major|partial|minor|complete)$/smx, "\$update->$key() produces an allowed type:" . $update->$key());
						} else {
							ok(1, "\$update->$key() produces a result:" . $update->$key());
						}
					} else {
						ok(1, "\$update->$key() produces undef");
					}
				}
				$update = $firefox->update();
				if (defined $update->app_version()) {
					diag("New Browser version is " . $update->app_version());
					$original_agent = $firefox->agent();
					diag("New User Agent is $original_agent");
					($major_version, $minor_version, $patch_version) = split /[.]/smx, $update->app_version();
					if ($major_version == 102) { # This was a bad firefox version for marionette.  It blew up when loading metacpan.org
						$ENV{FIREFOX_NO_NETWORK} = 1;
					}
				}
			}
		} elsif (defined $update->number_of_updates()) {
			ok(1, "Firefox was NOT updated");
			ok($update->number_of_updates() =~ /^\d+$/smx, "There were " . $update->number_of_updates() . " updates available");
		} else {
			diag("Unable to determine the number of updates available");
			ok(1, "Unable to determine the number of updates available");
		}
		$update = Firefox::Marionette::UpdateStatus->new(elevation_failure => 0, unsupported => undef, is_complete_update => 1, install_date => undef);
		ok(ref $update eq 'Firefox::Marionette::UpdateStatus', "Firefox::Marionette::UpdateStatus->new() produces a Firefox::Marionette::UpdateStatus object");
		ok($update->elevation_failure() == 0, "\$update->elevation_failure() == 0 when parameter is 0");
		ok(!defined $update->unsupported(), "\$update->unsupported() is not defined when parameter is not defined");
		ok($update->is_complete_update() == 1, "\$update->is_complete_update() == 1 when parameter is 1");
		ok(!defined $update->install_date(), "\$update->install_date() is not defined when parameter is not defined");
	}
	if ($ENV{FIREFOX_HOST}) {
		ok(-d $firefox->ssh_local_directory(), "Firefox::Marionette->ssh_local_directory() returns the existing ssh local directory:" . $firefox->ssh_local_directory());
	} else {
		ok(-d $firefox->root_directory(), "Firefox::Marionette->root_directory() returns the exising local directory:" . $firefox->root_directory());
	}
	ok($firefox->application_type(), "\$firefox->application_type() returns " . $firefox->application_type());
	ok($firefox->marionette_protocol() =~ /^\d+$/smx, "\$firefox->marionette_protocol() returns " . $firefox->marionette_protocol());
	my $window_type = $firefox->window_type();
	ok($window_type && $window_type eq 'navigator:browser', "\$firefox->window_type() returns 'navigator:browser':$window_type");
	ok($firefox->sleep_time_in_ms() == 1, "\$firefox->sleep_time_in_ms() is 1 millisecond");
	my $new_x = 3;
	my $new_y = 23;
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
	ok((ref $timeouts) eq 'Firefox::Marionette::Timeouts', "\$firefox->timeouts(\$new) returns a Firefox::Marionette::Timeouts object");
	if ($ENV{RELEASE_TESTING}) {
		$firefox->restart();
		my $restart_timeouts = $firefox->timeouts();
		ok($restart_timeouts->page_load() == $page_timeout, "\$timeouts->page_load() is $page_timeout");
		ok($restart_timeouts->script() == $script_timeout, "\$timeouts->script() is $script_timeout");
		ok($restart_timeouts->implicit() == $implicit_timeout, "\$timeouts->implicit() is $implicit_timeout");
	}
	my $timeouts2 = $firefox->timeouts();
	ok((ref $timeouts2) eq 'Firefox::Marionette::Timeouts', "\$firefox->timeouts() returns a Firefox::Marionette::Timeouts object");
	ok($timeouts->page_load() == 300_000, "\$timeouts->page_load() is 5 minutes");
	ok($timeouts->script() == 30_000, "\$timeouts->script() is 30 seconds");
	ok(defined $timeouts->implicit() && $timeouts->implicit() == 0, "\$timeouts->implicit() is 0 milliseconds");
	$timeouts = $firefox->timeouts($new);
	ok($timeouts->page_load() == $page_timeout, "\$timeouts->page_load() is $page_timeout");
	ok($timeouts->script() == $script_timeout, "\$timeouts->script() is $script_timeout");
	ok($timeouts->implicit() == $implicit_timeout, "\$timeouts->implicit() is $implicit_timeout");
	if ($major_version >= $min_stealth_version) {
		TODO: {
			local $TODO = "Some installations of firefox can default to webdriver being off"; # such as http://www.cpantesters.org/cpan/report/a0532bce-c32c-11ee-ae2f-883f6e8775ea (FreeBSD 14.0-STABLE) (BuildID 20240123011445)
			my $webdriver = $firefox->script('return navigator.webdriver');
			ok($webdriver, "navigator.webdriver returns true:" . (defined $webdriver ? $webdriver : q[undef]));
		}
	}
	ok(!defined $firefox->child_error(), "Firefox does not have a value for child_error");
	ok($firefox->alive(), "Firefox is still alive");
	ok(not($firefox->script('window.open("about:blank", "_blank");')), "Opening new window to about:blank via 'window.open' script");
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

my $metacpan_bookmark_icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAGbElEQVRYhcWWTWwV1xXHf+fcO8/PNjYFTFH5MIJNJJQIDE0LwU4faRaojUQlJHaITbtglVUWjbpwF0gsk32zqCxFFUiVsijpJvIjDkppagG1RMTG1FZJRWMixd+emXtPF2/med7DJptKudLTzJt77v/8z/eFypoEzwvWd+0D3AD3YoxGB4ZUwc9B/tHQSwP7BnsvR3MNLO5B9JlKaD5dXJu4sPBoqZTbTvklCAB3jo5cJMpbIhwSs1Ww6TyGibH5mdlx0HEwwKSq/G+HT/zC0D8OJMlQIBIBBRzKUpYtCPHK6bn7t7YiUSqfGn7lqPf+Zr/6kwCx2PcoyzEH4m9Pz967biACJlXlPUnylxCNzGIKpkKLJkhMRGtOhY0s+2U3icKi+MnB4wf6vP6zz/vdqyGk0jJQSgyBZKevyWK+fu2nj+//7gY4Afho6KWBH/b3zyZOh3ILGaIJZoaIbD5j5sUlWYgL/11ZOXph4dFSaYWBCsTPj5z8eIdLzq+EbB2ROma2GWwRzKJhse68X0+z0TPz9+8owL7B3ssDSTKUWUy3Vm6GaJJZTAeSZGjfYO9lgCYNVyqfOjBy3IueXw5pAHraykWkgqWAOUCde5sixERzjUAETNsHS+XlMjMwDUSiuUb5uUlDAZy30bo6ZDPstM9XMAVxaTQC4Sc3OFbT1kbcE6slUbLuApIyqSzuAWjQjJsiDLHd6sKLGGIy8KNh198iIPpM2wlXYdz130qXiT6rWt8SYaFq/HPnK5iKYGJL/5kPKwqgEpoOBSR2uK07iZDoUFRCs/xceiHk8tl6NKzg2GFIiSkihoWaCuD+fomHqQI8XVybWMqyhUS0hsWseqBaBYlobSnLFp4urk0UyoNANNCxJ/ce5Bb/usPVHLDxnCFFFQASAAnhfQCdBH9h4dGSEK84Fby4xMxSwwIWc8OCmaVeXOJUEOKVsiNKEbXfFwavZuHXy3n6Ta9zdTNLwXKwUGIA8gPf49OQXTszf/9Ouw98r52wBPi+ZkEHwP9jGnYk4ZYY20zDCoA0aThoZXhZakXCWbf8dyn6mqYB7KUht2nG8a5afY5AaUW1xhs0o2xb5FuvcdCfVTC+pmlleF54aDsXWituL3RvISfdbq6u7guLVDdKhlMHRo4n3kZNGDJjIeTy2diTew+65bYyoHTx7f0vH6p5fUPUHY6iqzEyPTo3PQmt8JyjmbcJlKCfHDx+oC9xf/Ci5+u6SXQ9BjLix2tp+M3P//3gyVYkSuUGcvfIyHvA1T7nEymclhNZy/OHJvnVs49nPrVWDwjSUb/qv9jha7uXQxqqMTfQHa7mlvP0mzzmr47Nz8yWY7h0e3EvkLvDJ5qDPfXXF0MGFrNqaOrOeYCVLLs4Ovfgz5M0vJaWeO9v9nm/eyVk64IoogmIRzQRRFdCtt7n/W7v/c3CdW2CZdXcPTLy3mBP/fVv83TNijtEG0PUr4eQZdHwqn+a2n9q+BzNXKHVNPrVn1wNIUWk3qJcuYwAiNRXQ0j71Z+8c3TkYhnLcdBzNPPb+18+BFxdDBlAXaoYxbuIJsFsY4erJT6J70CZ1VHealllm8OnOoiKdyk7ZyEPUJZazesbfc4nWMykOv+rU7V1qfEbFkD0zTYBNQ4W/pQuqzdBWu8SC3nYbDIAou5wmXAdE7D6KxQEMyDunRoe3lVcSGytSBQ62XY+N7W15Ksriq52fKjeqKo4LRKYkPbmezdKytO++0Ky5VNiS86modVeSy/EyHROxLq92EXIsOhVwPjyx19NrypAHsPEcshMIMEstgG6LhMCyXLILI9hAuA2zVhW0ejc9ORanj+sO+etvNRUMdphlJCgYPoBgE7S8GPzM7OIvbvT1wQsYjGzYlxai3QGFnf6miD27tj8zGxRARE226tJfhXAiSZitmFYpI1jwcw2dvqkZylPb702N/2hgeg5mvk46OnZe9cX8/VrPc77PueTRFRVRBNR7XM+6XHeL+br107P3rtell7p3UsQJmn4s49nPl3JsovRYtbvkp6aOqci6kS17rwfcEnPt1l6K/mX/mozH8q0av2xz4dPnFXn3g7EV8UYNGER9AsJ4f0z8/fvFF0PthjNZXud2n9q2CfxHUTfFOLeKKQYX2L6wWtz0x9C59xor+qkusGx2tTwK7tucKy21f52q3sSTg0P7/rH/lN9FZJilSH4Pylr2D7oCD10AAAAAElFTkSuQmCC';
my $metacpan_bookmark_icon_url = 'fake-favicon-uri:https://metacpan.org/pod/Firefox::Marionette';
my $metacpan_uri = 'https://metacpan.org/';

SKIP: {
	if (($ENV{FIREFOX_NO_RECONNECT})) {
		if ($ENV{FIREFOX_HOST}) {
			skip("$ENV{FIREFOX_HOST} is not supported for reconnecting yet", 8);
		} else {
			skip("$^O is not supported for reconnecting yet", 8);
		}
	} elsif (!$mozilla_pid_support) {
		skip("No pid support for this version of firefox", 8);
	} elsif (!$ENV{RELEASE_TESTING}) {
		skip("No survive testing except for RELEASE_TESTING", 8);
	}
	diag("Starting new firefox for testing reconnecting");
	($skip_message, $firefox) = start_firefox(0, debug => 'timestamp,cookie:2', survive => 1);
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
		ok(process_alive($firefox_pid), "Can contact firefox process ($firefox_pid)");
	}
	$firefox = undef;
	if (!$ENV{FIREFOX_HOST}) {
		ok(process_alive($firefox_pid), "Can contact firefox process ($firefox_pid)");
	}
	($skip_message, $firefox) = start_firefox(0, debug => 1, reconnect => 1);
	ok($firefox, "Firefox has reconnected in Marionette mode");
	$capabilities = $firefox->capabilities();
	ok($firefox_pid == $capabilities->moz_process_id(), "Firefox has the same process id");
	$firefox = undef;
	if (!$ENV{FIREFOX_HOST}) {
		ok(!process_alive($firefox_pid), "Cannot contact firefox process ($firefox_pid)");
	}
	if ($ENV{FIREFOX_HOST}) {
		if ($ENV{FIREFOX_BINARY}) {
			skip("No profile testing when the FIREFOX_BINARY override is used", 6);
		}
		if (!$ENV{RELEASE_TESTING}) {
			skip("No profile testing except for RELEASE_TESTING", 6);
		}
		if (($ENV{WATERFOX}) || ($ENV{WATERFOX_VIA_FIREFOX})) {
			skip("No profile testing when any WATERFOX override is used", 6);
		}
		if ($ENV{FIREFOX_DEVELOPER}) {
			skip("No profile testing when the FIREFOX_DEVELOPER override is used", 6);
		}
		if ($ENV{FIREFOX_NIGHTLY}) {
			skip("No profile testing when the FIREFOX_NIGHTLY override is used", 6);
		}
		my $name = 'throw';
		($skip_message, $firefox) = start_firefox(0, debug => 1, profile_name => $name );
		if (!$skip_message) {
			$at_least_one_success = 1;
		}
		if ($skip_message) {
			skip($skip_message, 6);
		}
		ok($firefox, "Firefox has started in Marionette mode with a profile_name");
		my $capabilities = $firefox->capabilities();
		ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
		my $firefox_pid = $capabilities->moz_process_id();
		ok($firefox_pid, "Firefox process has a process id of $firefox_pid when using a profile_name");
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
	} else {
		if ($ENV{FIREFOX_BINARY}) {
			skip("No profile testing when the FIREFOX_BINARY override is used", 6);
		}
		if (!$ENV{RELEASE_TESTING}) {
			skip("No profile testing except for RELEASE_TESTING", 6);
		}
		if (($ENV{WATERFOX}) || ($ENV{WATERFOX_VIA_FIREFOX})) {
			skip("No profile testing when any WATERFOX override is used", 6);
		}
		if ($ENV{FIREFOX_DEVELOPER}) {
			skip("No profile testing when the FIREFOX_DEVELOPER override is used", 6);
		}
		if ($ENV{FIREFOX_NIGHTLY}) {
			skip("No profile testing when the FIREFOX_NIGHTLY override is used", 6);
		}
		my $found;
		my @names = Firefox::Marionette::Profile->names();
		foreach my $name (@names) {
			if ($name eq 'throw') {
				$found = 1;
			}
		}
		if (!$found) {
			skip("No profile testing when throw profile doesn't exist", 6);
		}
		my $name = 'throw';
		($skip_message, $firefox) = start_firefox(0, debug => 1, har => 1, survive => 1, profile_name => $name );
		if (!$skip_message) {
			$at_least_one_success = 1;
		}
		if ($skip_message) {
			skip($skip_message, 8);
		}
		ok($firefox, "Firefox has started in Marionette mode with as survivable with a profile_name and har");
		my $capabilities = $firefox->capabilities();
		ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
		my $firefox_pid = $capabilities->moz_process_id();
		ok($firefox_pid, "Firefox process has a process id of $firefox_pid when using a profile_name");
		ok(process_alive($firefox_pid), "Can contact firefox process ($firefox_pid) when using a profile_name");
		$firefox = undef;
		ok(process_alive($firefox_pid), "Can contact firefox process ($firefox_pid) when using a profile_name");
		($skip_message, $firefox) = start_firefox(0, debug => 1, reconnect => 1, profile_name => $name);
		ok($firefox, "Firefox has reconnected in Marionette mode when using a profile_name");
		ok($firefox_pid == $capabilities->moz_process_id(), "Firefox has the same process id when using a profile_name");
		$firefox = undef;
		ok(!process_alive($firefox_pid), "Cannot contact firefox process ($firefox_pid)");
	}
}

if ($^O eq 'MSWin32') {
} elsif ($ENV{RELEASE_TESTING}) {
	eval {
		$ca_cert_handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_ca_cert_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
		fcntl $ca_cert_handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
		$ca_private_key_handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_ca_private_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
		system {'openssl'} 'openssl', 'genrsa', '-out' => $ca_private_key_handle->filename(), 4096 and Carp::croak("Failed to generate a private key:$!");
		my $ca_config_handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_ca_config_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
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
		system {'openssl'} 'openssl', 'req', '-new', '-x509',
			'-set_serial' => '1',
			'-config'     => $ca_config_handle->filename(),
			'-days'       => 10,
			'-key'        => $ca_private_key_handle->filename(),
			'-out'        => $ca_cert_handle->filename()
			and Carp::croak("Failed to generate a CA root certificate:$!");
		1;
	} or do {
		chomp $@;
		diag("Did not generate a CA root certificate:$@");
	};
}

SKIP: {
	diag("Starting new firefox for testing capabilities and accessing proxies");
	my $daemon = HTTP::Daemon->new(LocalAddr => 'localhost') || die "Failed to create HTTP::Daemon";
	my $proxyPort = URI->new($daemon->url())->port();
	my $securePort = empty_port();
	diag("Using proxy port TCP/$proxyPort");
	my $socksPort = empty_port();
	diag("Using SOCKS port TCP/$socksPort");
	my %proxy_parameters = (http => 'localhost:' . $proxyPort, https => 'localhost:' . $securePort, none => [ 'local.example.org' ], socks => 'localhost:' . $socksPort);
	my $ftpPort = empty_port();
	if ($binary =~ /waterfox/i) {
	} elsif ((defined $major_version) && ($major_version < 90)) {
		diag("Using FTP port TCP/$ftpPort");
		$proxy_parameters{ftp} = 'localhost:' . $ftpPort;
	}
	my $proxy = Firefox::Marionette::Proxy->new(%proxy_parameters);
	my $bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_edge.html));
	if ($major_version == 38) {
		skip("Skipping b/c of segmentation faults for proxy capabilities", 6);
	}
	($skip_message, $firefox) = start_firefox(0, kiosk => 1, sleep_time_in_ms => 5, profile => $profile, capabilities => Firefox::Marionette::Capabilities->new(proxy => $proxy, moz_headless => 1, strict_file_interactability => 1, accept_insecure_certs => 1, page_load_strategy => 'eager', unhandled_prompt_behavior => 'accept and notify', moz_webdriver_click => 1, moz_accessibility_checks => 1, moz_use_non_spec_compliant_pointer_origin => 1, timeouts => Firefox::Marionette::Timeouts->new(page_load => 54_321, script => 4567, implicit => 6543)), bookmarks => $bookmarks_path);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 26);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	if ($major_version < 61) {
		skip("HAR support not available in Firefox before version 61", 1);
	} else {
		my $har_lives = 0;
		eval { $firefox->har(); $har_lives = 1 };
		chomp $@;
		ok($har_lives == 0 && $@ =~ /^(?:webdriver|javascript|unknown)[ ]error:[ ]TypeError:[ ](?:can't[ ]access[ ]property[ ]"triggerExport",[ ])?window[.]HAR[ ]is[ ]undefined[ ]at[ ]t[\/\\]01\-marionette.t[ ]line[ ]\d+/smx, "\$firefox->har() throws an exception when har has not been setup:$@");
	}
	if ($major_version >= 60) {
		my ($bookmark) = $firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') });
		ok($bookmark, "Retrieved bookmark from edge import");
		ok(ref $bookmark->url() eq 'URI::URL', "\$bookmark->url() returns a URI::URL object");
		ok($bookmark->url() eq $metacpan_uri . 'pod/Firefox::Marionette', "\$bookmark->url() is '${metacpan_uri}pod/Firefox::Marionette':" . $bookmark->url());
		ok($bookmark->date_added() == 1685610972, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->title() eq 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org', "\$bookmark->title() is 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() " . $bookmark->parent_guid());
		ok($bookmark->guid(), "\$bookmark->guid() is " . $bookmark->guid());
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new('https://perlmonks.org/') });
		ok($bookmark->url() eq 'https://perlmonks.org/', "\$bookmark->url() is 'https://perlmonks.org/':" . $bookmark->url());
		ok($bookmark->date_added() == 1686364081, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->title() eq 'PerlMonks - The Monastery Gates', "\$bookmark->title() is 'PerlMonks - The Monastery Gates':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid(), "\$bookmark->guid() is " . $bookmark->guid());
		ok(!defined $bookmark->icon_url(), "\$bookmark->icon_url() is not defined");
		ok(!defined $bookmark->icon(), "\$bookmark->icon() is not defined");
	}
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
			my $moz_use_non_spec_compliant_pointer_origin = $capabilities->moz_use_non_spec_compliant_pointer_origin();
			if (defined $moz_use_non_spec_compliant_pointer_origin) {
				ok($moz_use_non_spec_compliant_pointer_origin == 0, "\$capabilities->moz_use_non_spec_compliant_pointer_origin() is set to false");
			} else {
				ok(1, "\$capabilities->moz_use_non_spec_compliant_pointer_origin() is not defined");
			}
		} else {
			ok($capabilities->moz_use_non_spec_compliant_pointer_origin() == 1, "\$capabilities->moz_use_non_spec_compliant_pointer_origin() is set to true");
		}
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
		ok($capabilities->proxy()->http() eq 'localhost:' . $proxyPort, "\$capabilities->proxy()->http() is 'localhost:" . $proxyPort . "':" . $capabilities->proxy()->http());
		ok($capabilities->proxy()->https() eq 'localhost:' . $securePort, "\$capabilities->proxy()->https() is 'localhost:" . $securePort . "'");
		if ($major_version < 90) {
			ok($capabilities->proxy()->ftp() eq 'localhost:' . $ftpPort, "\$capabilities->proxy()->ftp() is 'localhost:$ftpPort'");
		}
		ok($capabilities->timeouts()->page_load() == 54_321, "\$capabilities->timeouts()->page_load() is '54,321'");
		ok($capabilities->timeouts()->script() == 4567, "\$capabilities->timeouts()->script() is '4,567'");
		ok($capabilities->timeouts()->implicit() == 6543, "\$capabilities->timeouts()->implicit() is '6,543'");
		my $none = 0;
		foreach my $host ($capabilities->proxy()->none()) {
			$none += 1;
		}
		ok($capabilities->proxy()->socks() eq 'localhost:' . $socksPort, "\$capabilities->proxy()->socks() is 'localhost:$socksPort':" . $capabilities->proxy()->socks() );
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
		} elsif ($^O eq 'cygwin') {
			skip("\$capabilities->proxy is not supported for $^O", 1);
		} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
			if ($ENV{RELEASE_TESTING}) {
				my $handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_proxy_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
				fcntl $handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
				if (my $pid = fork) {
					my $url = 'http://wtf.example.org';
					my $favicon_url = 'http://wtf.example.org/favicon.ico';
					wait_for_server_on($daemon, $daemon->url(), $pid);
					$daemon = undef;
					my $try_count = 0;
					GO: {
						eval {
							$firefox->go($url);
						} or do {
							if ($try_count < 2) {
								diag("Failed to get $url via proxy on attempt $try_count for $version_string");
								$try_count += 1;
								redo GO;
							} else {
								diag("Failed to get $url via proxy too many times $version_string");
							}
						};
					}
					ok($firefox->html() =~ /success/smx, "Correctly accessed the Proxy");
					diag($firefox->html());
					$handle->seek(0,0) or die "Failed to seek to start of temporary file for proxy check:$!";
					my $quoted_url = quotemeta $url;
					my $quoted_favicon_url = quotemeta $favicon_url;
					while(my $line = <$handle>) {
						chomp $line;
						if ($line =~ /^$favicon_url$/smx) {
						} elsif ($line !~ /^$quoted_url\/?$/smx) {
							die "Firefox is requesting this $line without any reason";
						}
					}
					while(kill 0, $pid) {
						kill $signals_by_name{TERM}, $pid;
						sleep 1;
						waitpid $pid, POSIX::WNOHANG();
					}
					ok($! == POSIX::ESRCH(), "Process $pid no longer exists:$!");
				} elsif (defined $pid) {
					eval 'Devel::Cover::set_coverage("none")' if $is_covering;
					eval {
						local $SIG{ALRM} = sub { die "alarm during proxy server\n" };
						alarm 40;
						$0 = "[Test HTTP Proxy for " . getppid . "]";
						diag("Accepting connections for $0");
						while (my $connection = $daemon->accept()) {
							diag("Accepted connection");
							if (my $child = fork) {
							} elsif (defined $child) {
								eval {
									local $SIG{ALRM} = sub { die "alarm during proxy server accept\n" };
									alarm 40;
									while (my $request = $connection->get_request()) {
										diag("Got request for " . $request->uri());
										$handle->print($request->uri() . "\n");
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
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	my $proxyPort = empty_port();
	my $latitude = 40;
	my $longitude = 24;
	my $geo1 = Firefox::Marionette::GeoLocation->new(lat => $latitude, lng => $longitude);
	diag("Starting new firefox for testing proxies with proxy port TCP/$proxyPort");
	if (($major_version == 45) || ($major_version == 38)) {
		skip("Skipping b/c of segmentation faults for proxy capabilities", 6);
	}
	($skip_message, $firefox) = start_firefox(0, chatty => 1, devtools => 1, page_load => 65432, capabilities => Firefox::Marionette::Capabilities->new(proxy => Firefox::Marionette::Proxy->new( pac => URI->new('http://localhost:' . $proxyPort)), moz_headless => 1), geo => $geo1);
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
		ok($capabilities->proxy()->pac()->host() eq 'localhost', "\$capabilities->proxy()->pac()->host() is 'localhost'");
	}
	ok($capabilities->timeouts()->page_load() == 65432, "\$firefox->capabilities()->timeouts()->page_load() correctly reflects the page_load shortcut timeout");
	if ($ENV{FIREFOX_HOST}) {
	} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
	} elsif ($major_version >= $min_geo_version) {
		my $path = File::Spec->catfile(Cwd::cwd(), qw(t data elements.html));
		if ($^O eq 'cygwin') {
			$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
		}
		$firefox->go("file://$path");
		my $geo2;
		eval { $geo2 = $firefox->geo(); };
		if ((!defined $geo2) && (($uname eq 'cygwin') || ($uname eq 'MSWin32'))) {
			diag("Location services may be disabled:$@");
			eval {
				$firefox->dismiss_alert();
			};
		} elsif (defined $geo2) {
			my $returned_latitude = $geo2->latitude();
			my $returned_longitude = $geo2->longitude();
			ok($returned_latitude == $latitude, "\$geo2->latitude() is correctly reported as $latitude:$returned_latitude");
			ok($returned_longitude == $longitude, "\$geo2->longitude() is correctly reported as $longitude:$returned_longitude");
		}
	}
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	my $proxyPort = Firefox::Marionette::Proxy::DEFAULT_SQUID_PORT();
	diag("Starting new firefox for testing proxies again using default proxy port TCP/$proxyPort");
	my $visible = 1;
	if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_USER})) {
		$visible = 'local';
	}
	if ($major_version == 38) {
		skip("Skipping b/c proxy must be undefined", 7);
	}
	if ($major_version >= 135) {
		skip("Skipping b/c proxy seems to cause hangs", 7);
	}
	($skip_message, $firefox) = start_firefox($visible, seer => 1, chatty => 1, capabilities => Firefox::Marionette::Capabilities->new(proxy => Firefox::Marionette::Proxy->new( host => 'localhost', none => 'localhost')));
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
		ok($capabilities->proxy()->https() eq 'localhost:' . $proxyPort, "\$capabilities->proxy()->https() is 'localhost:$proxyPort'");
		ok($capabilities->proxy()->http() eq 'localhost:' . $proxyPort, "\$capabilities->proxy()->http() is 'localhost:$proxyPort'");
		local $TODO = $major_version < 58 ? $capabilities->browser_version() . " does not have support for \$firefox->capabilities()->none()" : q[];
		my $none_count = 0;
		foreach my $host ($capabilities->proxy()->none()) {
			ok($host eq 'localhost', "\$capabilities->proxy()->none() is 'localhost'");
			$none_count += 1;
		}
		ok($none_count == 1, "Number of none proxies is 1:$none_count");
	}
	if (($ENV{RELEASE_TESTING}) && ($visible eq 'local')) {
		`xwininfo -version 2>/dev/null`;
		if ($? == 0) {
			require Crypt::URandom;
			my $string = join q[], unpack("h*", Crypt::URandom::urandom(20));
			$firefox->script('window.document.title = arguments[0]', args => [ $string ]);
			my $found_window = `xwininfo -root -tree | grep $string`;
			chomp $found_window;
			ok($found_window, "Found X11 Forwarded window:$found_window");
			my $pid = $capabilities->moz_process_id();
			if (defined $pid) {
				my $command = "ps axo pid,user,cmd | grep -E '^[ ]+$pid\[ \]+$ENV{FIREFOX_USER}\[ \]+.+firefox[ ]\-marionette[ ]\-safe\-mode[ ]\-profile[ ].*/profile[ ]\-\-no\-remote[ ]\-\-new\-instance[ ]*\$'";
				my $process_listing = `$command`;
				chomp $process_listing;
				ok($process_listing =~ /^[ ]+$pid/, "Found X11 Forwarded process:$process_listing");
			}
		}
	}
	my $child_error = $firefox->quit();
	if (($major_version < 50) && ($ENV{RELEASE_TESTING}) && ($visible eq 'local')) {
		$correct_exit_status = $child_error;
	}
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	diag("Starting new firefox for testing PDFs and script elements");
	my $bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_chrome.html));
	($skip_message, $firefox) = start_firefox(0, insecure => 1, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 1), bookmarks => $bookmarks_path, geo => 1, stealth => 1);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 6);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	if ($major_version < 30) {
		diag("Skipping WebGL as it can cause older browsers to hang");
	} elsif ($firefox->script(q[let c = document.createElement('canvas'); return c.getContext('webgl2') ? true : c.getContext('experimental-webgl') ? true : false;])) {
		diag("WebGL is enabled by default when visible and addons are turned off");
	} else {
		diag("WebGL is disabled by default when visible and addons are turned off");
	}
	if ($major_version >= 60) {
		my ($bookmark) = $firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') });
		ok($bookmark, "Retrieved bookmark from chrome import as " . $bookmark->url());
		ok($bookmark->url() eq $metacpan_uri . 'pod/Firefox::Marionette', "\$bookmark->url() is '${metacpan_uri}pod/Firefox::Marionette':" . $bookmark->url());
		ok($bookmark->date_added() == 1685610972, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->title() eq 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org', "\$bookmark->title() is 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid(), "\$bookmark->guid() is " . $bookmark->guid());
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new('https://perlmonks.org/') });
		ok($bookmark->url() eq 'https://perlmonks.org/', "\$bookmark->url() is 'https://perlmonks.org/':" . $bookmark->url());
		ok($bookmark->date_added() == 1686364081, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->title() eq 'PerlMonks - The Monastery Gates', "\$bookmark->title() is 'PerlMonks - The Monastery Gates':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid(), "\$bookmark->guid() is " . $bookmark->guid());
		ok(!defined $bookmark->icon_url(), "\$bookmark->icon_url() is not defined");
		ok(!defined $bookmark->icon(), "\$bookmark->icon() is not defined");
	}
	if ($ENV{FIREFOX_HOST}) {
	} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
	} elsif ($arch =~ /$arch_32bit_re/smx) {
		diag("aria tests can cause hangs in 32 bit architectures.  See debian failures such as https://tests.reproducible-builds.org/debian/rbuild/trixie/armhf/libfirefox-marionette-perl_1.53-1.rbuild.log.gz");
	} elsif ($major_version >= 113) { # https://bugzilla.mozilla.org/show_bug.cgi?id=1585622
		my $path = File::Spec->catfile(Cwd::cwd(), qw(t data aria.html));
		if ($^O eq 'cygwin') {
			$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
		}
		$firefox->go("file://$path");
		my $element = $firefox->find_id('close');
		ok($firefox->aria_label($element) eq 'Close', "Retrieved the ARIA label correctly:" . $firefox->aria_label($element));
		ok($firefox->find_id('close')->aria_label() eq 'Close', "Retrieved the ARIA label correctly:" . $firefox->find_id('close')->aria_label());
		$element = $firefox->find_id('save');
		ok($firefox->aria_role($element) =~ /^(?:toggle[ ])?button$/smx, "Retrieved the ARIA role correctly:" . $firefox->aria_role($element));
		ok($firefox->find_id('save')->aria_role() =~ /^(?:toggle[ ])?button$/smx, "Retrieved the ARIA label correctly:" . $firefox->find_id('save')->aria_role());
	}
	if ($major_version > 32) { # https://bugzilla.mozilla.org/show_bug.cgi?id=889335
		my $browser_language = join q[, ], @{$firefox->script('return navigator.languages')};
		my $original_language = join q[, ], $firefox->languages();
		ok($original_language eq $browser_language, "\$firefox->languages() equals navigator.languages:'$original_language' vs '$browser_language'");
		my $new_language = 'en-AU, en-GB, en';
		ok((join q[, ], $firefox->languages(split q[, ], $new_language)) eq $original_language, "\$firefox->languages(split q[, ], \"$new_language\") returns correctly");
		$browser_language = join q[, ], @{$firefox->script('return navigator.languages')};
		ok($new_language eq $browser_language, "\$firefox->languages() equals navigator.languages:'$new_language' vs '$browser_language'");
		my $lone_language = 'en-GB';
		ok((join q[, ], $firefox->languages($lone_language)) eq $new_language, "\$firefox->languages(\"$lone_language\") returns correctly");
		$browser_language = join q[, ], @{$firefox->script('return navigator.languages')};
		ok($lone_language eq $browser_language, "\$firefox->languages() matches navigator.language b/c there is only one entry:'$lone_language' vs '$browser_language'");
	} else {
		my $browser_language = $firefox->chrome()->script('return Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("").getComplexValue("intl.accept_languages", Components.interfaces.nsIPrefLocalizedString).data;');
		$firefox->content();
		my $original_language = join q[, ], $firefox->languages();
		ok($original_language eq $browser_language, "\$firefox->languages() equals navigator.languages:'$original_language' vs '$browser_language'");
	}
	my $test_agent_string = "Firefox::Marionette v$Firefox::Marionette::VERSION test suite";
	ok($firefox->agent($test_agent_string) eq $original_agent, "\$firefox->agent(\$test_agent_string) returns the original user agent string of '$original_agent'");
	my $shadow_root;
	my $path;
	if ($ENV{FIREFOX_HOST}) {
	} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
	} else {
		$path = File::Spec->catfile(Cwd::cwd(), qw(t data elements.html));
		if ($^O eq 'cygwin') {
			$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
		}
		ok($firefox->go("file://$path"), "\$firefox->go(\"file://$path\") loaded successfully");
		my $new_agent = $firefox->agent(undef);
		ok($new_agent eq $test_agent_string, "\$firefox->agent(undef) returns '$test_agent_string':$new_agent");
		my $element = $firefox->find_class('add');
		ok($firefox->delete_element($element), "Deleted element with 'add' class");
		ok(!$firefox->has_class('add'), "Deleted 'add' element cannot be found in the DOM");
		$element = $firefox->find_class('update');
		ok($element->delete_element($element), "Deleted element with 'update' class");
		ok(!$firefox->has_class('update'), "Deleted 'update' element cannot be found in the DOM");
		ok($firefox->go("file://$path"), "\$firefox->go(\"file://$path\") loaded successfully again");
		my $final_agent = $firefox->agent();
		ok($final_agent eq $original_agent, "\$firefox->agent() returns the original user agent string '$original_agent':$final_agent");
		$firefox->find_class('add')->click();
		my $span = $firefox->has_tag('span');
		{
			my $count = 0;
			my $element = $firefox->script('return arguments[0].children[0]', args => [ $span ]);
			ok(ref $element eq 'Firefox::Marionette::Element' && $element->tag_name() eq 'button', "\$firefox->has_tag('span') has children and the first child is an Firefox::Marionette::Element with a tag_name of 'button'");
		}
		my $custom_square;
		TODO: {
			local $TODO = $major_version < 63 ? "Firefox cannot create elements from a shadow root for versions less than 63" : undef;
			$custom_square = $firefox->has_tag('custom-square');
			ok(ref $custom_square eq 'Firefox::Marionette::Element', "\$firefox->has_tag('custom-square') returns a Firefox::Marionette::Element");
			if (ref $custom_square eq 'Firefox::Marionette::Element') {
				my $element = $firefox->script('return arguments[0].shadowRoot.children[0]', args => [ $custom_square ]);
				ok(!$span->shadowy(), "\$span->shadowy() returns false");
				ok($custom_square->shadowy(), "\$custom_square->shadowy() returns true");
				ok($element->tag_name() eq 'style', "First element from scripted shadowRoot is a style tag");
			}
		}
		if ($major_version >= 96) {
			$shadow_root = $custom_square->shadow_root();
			ok(ref $shadow_root eq 'Firefox::Marionette::ShadowRoot', "\$firefox->has_tag('custom-square')->shadow_root() returns a Firefox::Marionette::ShadowRoot");
			my $count = 0;
			foreach my $element (@{$firefox->script('return arguments[0].children', args => [ $shadow_root ])}) {
				if ($count == 0) {
					ok($element->tag_name() eq 'style', "First element from ShadowRoot via script is a style tag");
				} elsif ($count == 1) {
					ok($element->tag_name() eq 'div', "Second element from ShadowRoot via script is a div tag");
				}
				$count += 1;
			}
			ok($count == 6, "\$firefox->has_tag('custom-square')->shadow_root() has 2 children:$count");
			ok(ref $shadow_root eq 'Firefox::Marionette::ShadowRoot', "\$firefox->has_tag('custom-square')->shadow_root() returns a Firefox::Marionette::ShadowRoot");
			{
				my $element = $firefox->script('return arguments[0].children[0]', args => [ $shadow_root ]);
				ok($element->tag_name() eq 'style', "Element returned from ShadowRoot via script is a style tag");
			}
			$count = 0;
			foreach my $element (@{$firefox->script('return [ 2, arguments[0].children[0] ]', args => [ $shadow_root ])}) {
				if ($count == 0) {
					ok($element == 2, "First element is the numeric 2");
				} else {
					ok($element->tag_name() eq 'style', "Second element from ShadowRoot via script is a style tag");
				}
				$count += 1;
			}
			ok($count == 2, "\$firefox->script() correctly returns an array with 2 elements");
			if ($major_version >= 113) {
				ok($firefox->find_id('outer-div', $shadow_root)->attribute('title') eq 'In the Shadow Realms', "Correctly found shadow element with find_id");
				my $shadow_count = 0;
				foreach my $span ($firefox->has_tag('span', $shadow_root)) {
					ok($span->tag_name() eq 'span', "Correctly found shadow span with find_tag");
					$shadow_count += 1;
				}
				ok($shadow_count == 2, "There are 2 span elements in the custom-square element");
				$shadow_count = 0;
				foreach my $span ($firefox->has_tag('notag', $shadow_root)) {
					$shadow_count += 1;
				}
				ok($shadow_count == 0, "There are 0 notag elements in the custom-square element");
				ok($firefox->find_name('meta-name', $shadow_root)->attribute('title') eq 'Very META', "Correctly found shadow element with find_name");
				ok($firefox->find_class('outer-div-class', $shadow_root)->attribute('title') eq 'In the Shadow Realms', "Correctly found shadow element with find_class");
				ok($firefox->find_link('MetaCPAN', $shadow_root)->attribute('href') eq 'https://metacpan.org', "Correctly found shadow element with find_link");
				ok($firefox->find_partial('Meta', $shadow_root)->attribute('href') eq 'https://metacpan.org', "Correctly found shadow element with find_partial");
				TODO: {
					local $TODO = "xpath is not supported as a strategy for find in the shadow DOM";
					my $title = q[];
					eval {
						$title = $firefox->find('//div', $shadow_root)->attribute('title');
					};
					ok($title eq 'In the Shadow Realms', "Correctly found shadow element with find (xpath):$title");
				}
			}
		}
		{
			my $value = $firefox->script('return [2,1]', args => [ $span ]);
			ok($value->[0] == 2, "Value returned from script is the numeric 2 in an array");
		}
		{
			my $value = $firefox->script('return [2,arguments[0]]', args => [ $span ]);
			ok(ref $value->[1] eq 'Firefox::Marionette::Element' && $value->[1]->tag_name() eq 'span', "Value returned from script is a Firefox::Marionette::Element for a 'span' in an array");
		}
		{
			my $value = $firefox->script('return arguments[0]', args => { elem => $span });
			ok(ref $value->{elem} eq 'Firefox::Marionette::Element' && $value->{elem}->tag_name() eq 'span', "Value returned from script is a Firefox::Marionette::Element for a 'span' in a hash");
		}
		{
			my $value = $firefox->script('return 2', args => [ $span ]);
			ok($value == 2, "Value returned from script is the numeric 2");
		}
		{
			my $hash = $firefox->script('return { value: 2 }', args => [ $span ]);
			ok($hash->{value} == 2, "Value returned from script is the numeric 2 in a hash");
		}
	}
	my $webdriver = $firefox->script('return navigator.webdriver');
	ok(!$webdriver, "navigator.webdriver returns false when stealth is on");
	if (($tls_tests_ok) && ($ENV{RELEASE_TESTING})) {
		$firefox->chrome();
		foreach my $name (@Firefox::Marionette::DNS::EXPORT_OK) {
			my $correct = $firefox->script("return Components.interfaces.nsIDNSService.$name");
			my $actual = eval "return Firefox::Marionette::DNS::$name();";
			local $TODO = ($major_version < 115 && $name =~ /^((?:RESOLVE_(?:TYPE_DEFAULT|TYPE_TXT|TYPE_HTTPSSVC|ALLOW_NAME_COLLISION|DISABLE_TRR|REFRESH_CACHE|TRR_MODE_MASK|TRR_DISABLED_MODE|IGNORE_SOCKS_DNS|IP_HINT|WANT_RECORD_ON_ERROR))|ALL_DNSFLAGS_BITS)$/smx) ? "Older firefox (less than 115) can have different values for Firefox::Marionette::DNS constants" : q[];
			local $TODO = $TODO || (($major_version < 130 && $name =~ /^((?:RESOLVE_(?:CREATE_MOCK_HTTPS_RR|DISABLE_NATIVE_HTTPS_QUERY))|ALL_DNSFLAGS_BITS)$/smx) ? "Older firefox (less than 130) can have different values for Firefox::Marionette::DNS constants" : q[]);
			ok(defined $correct && defined $actual && $correct == $actual, "Firefox::Marionette::DNS::$name() ($actual) matches the value in firefox (" . (defined $correct ? $correct : "null") . ")");
		}
		$firefox->content();
		if ($major_version >= 52) {
			foreach my $result ($firefox->resolve('localhost')) {
				ok($result =~ /^(127[.]0[.]0[.]1|::1)/smx, "\$firefox->resolve('localhost') returned correctly:$result");
			}
			foreach my $result ($firefox->resolve('localhost', type => 0, flags => 0)) {
				ok($result =~ /^(127[.]0[.]0[.]1|::1)/smx, "\$firefox->resolve('localhost', type => 0, flags => 0) returned correctly:$result");
			}
			if ($major_version >= 78) {
				my $test_dns_name = 'custom-weird.example.com';
				my $ip_address = '127.0.0.84';
				foreach my $result ($firefox->resolve_override($test_dns_name, $ip_address)->resolve($test_dns_name)) {
					ok($result eq $ip_address, "\$firefox->resolve_override('$test_dns_name', '$ip_address') worked correctly:$result");
				}
			}
		}
		my $json;
		if ($major_version < 50) {
			diag("\$firefox->json(\$url) calls aren't going to work for versions < 50");
		} else {
			$json = $firefox->json($freeipapi_uri);
			ok($json->{ipVersion} == 6, "\$firefox->json(\$url)->{ipVersion} returned 6:$json->{ipVersion}");
			ok($json->{ipAddress} eq '2001:8001:4ab3:d800:7215:c1fe:fc85:1329', "\$firefox->json(\$url)->{ipAddress} returned '2001:8001:4ab3:d800:7215:c1fe:fc85:1329':$json->{ipAddress}");
			ok($json->{latitude} == -37.5, "\$firefox->json(\$url)->{latitude} returned -31.5:$json->{latitude}");
			ok($json->{longitude} == 144.5, "\$firefox->json(\$url)->{longitude} returned 144.5:$json->{longitude}");
			ok($json->{timeZone} eq "+11:00", "\$firefox->json(\$url)->{timeZone} returned +11:00:$json->{timeZone}");
			$useragents_me_uri =~ s/[ ]/%20/smxg; # firefoxen older that 108 strips spaces from data uris: https://bugzilla.mozilla.org/show_bug.cgi?id=1104311
			my %user_agent_strings = map { $_->{ua} => $_->{pct} } @{$firefox->json($useragents_me_uri)->{data}};
			my ($user_agent) = reverse sort { $user_agent_strings{$a} <=> $user_agent_strings{$b} } keys %user_agent_strings;
			ok($user_agent eq $most_common_useragent, "Correctly sorted the most common user agent:'$user_agent' vs '$most_common_useragent'");
			ok($firefox->agent($most_common_useragent), "\$firefox->agent(\"\$most_common_useragent\") worked");
			if ($ENV{FIREFOX_HOST}) {
			} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
				diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
			} else {
				ok($firefox->go("file://$path"), "\$firefox->go(\"file://$path\") loaded successfully for user agent test");
				my $agent = $firefox->agent();
				ok($agent eq $most_common_useragent, "\$firefox->agent() now produces the most common user agent");
			}
		}
		if ($ENV{FIREFOX_HOST}) {
		} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		} elsif ($major_version >= $min_geo_version) {
			my %hosts = ($freeipapi_uri => 'freeipapi', $geocode_maps_uri => 'geocode_maps', $positionstack_uri => 'positionstack', $ipgeolocation_uri => 'ipgeolocation', $ipstack_uri => 'ipstack', $dummy1_uri => 'dummy1', $dummy2_uri => 'dummy2');
			foreach my $geo_uri ($freeipapi_uri, $geocode_maps_uri, $positionstack_uri, $ipgeolocation_uri, $ipstack_uri, $dummy1_uri, $dummy2_uri) {
				my $json = $firefox->json($geo_uri);
				if ($geo_uri eq $geocode_maps_uri) {
					$json = $json->[0];
				} elsif ($geo_uri eq $positionstack_uri) {
					$json = $json->{data}->[0];
				}
				my $sample = Firefox::Marionette::GeoLocation->new($json);
				my $latitude = $sample->latitude();
				my $longitude = $sample->longitude();
				if (($geo_uri eq $dummy1_uri) || ($geo_uri eq $dummy2_uri)) {
					ok($latitude == 40.7, "Firefox::Marionette::GeoLocation latitude from $hosts{$geo_uri} is 40.7:" . $latitude);
					ok($longitude == -73.9, "Firefox::Marionette::GeoLocation longitude from $hosts{$geo_uri} is -73.9:" . $longitude);
				} else {
					ok($latitude == -37.5, "Firefox::Marionette::GeoLocation latitude from $hosts{$geo_uri} is -37.5:" . $latitude);
					ok($longitude == 144.5, "Firefox::Marionette::GeoLocation longitude from $hosts{$geo_uri} is 144.5:" . $longitude);
				}
				my $timezone_offset = $sample->timezone_offset();
				if (($geo_uri eq $geocode_maps_uri) || ($geo_uri eq $positionstack_uri) || ($geo_uri eq $ipstack_uri) || ($geo_uri eq $dummy2_uri)) {
					ok(!defined $timezone_offset, "Firefox::Marionette::GeoLocation timezone offset from $hosts{$geo_uri} is not defined");
				} elsif ($geo_uri eq $dummy1_uri) {
					ok($timezone_offset == 300, "Firefox::Marionette::GeoLocation timezone offset from $hosts{$geo_uri} is 300:$timezone_offset");
				} else {
					ok(defined $timezone_offset, "Firefox::Marionette::GeoLocation timezone offset from $hosts{$geo_uri} is defined:$timezone_offset");
				}
				my $country_code = $sample->country_code();
				if (($geo_uri eq $geocode_maps_uri) || ($geo_uri eq $positionstack_uri) || ($geo_uri eq $dummy1_uri) || ($geo_uri eq $dummy2_uri)) {
					ok(!defined $country_code, "Firefox::Marionette::GeoLocation country_code from $hosts{$geo_uri} is not defined");
				} else {
					ok($country_code eq 'AU', "Firefox::Marionette::GeoLocation country_code from $hosts{$geo_uri} is 'AU':$country_code");
				}
			}
		}
		my $new_york = Firefox::Marionette::GeoLocation->new({ lat => 40.753, long => -73.983 });
		my $encoded_new_york = Encode::encode('UTF-8', "$new_york", 1);
		ok($encoded_new_york eq "40°45'11\"N,73°58'59\"W", "Correctly stringifies New York:$encoded_new_york");
		ok($new_york->uri()->isa('URI') && $new_york->uri() eq 'geo:40.753,-73.983', "\$geo->uri() correctly produces a URI:" . $new_york->uri());
		my $fountain_island = Firefox::Marionette::GeoLocation->new(latitude => -37.82896, longitude => 144.9811, accuracy => 40075017, altitude => 55, altitude_accuracy => 20, speed => 20);
		my $encoded_fountain_island = Encode::encode('UTF-8', "$fountain_island", 1);
		ok($encoded_fountain_island eq "37°49'44\"S,144°58'52\"E", "Correctly stringifies Fountain Island:$encoded_fountain_island");
		ok($fountain_island->uri()->isa('URI') && $fountain_island->uri() eq 'geo:-37.82896,144.9811,55;u=40075017', "\$geo->uri() correctly produces a URI:" . $fountain_island->uri());
		my ($latitude, $longitude);
		if ($ENV{FIREFOX_HOST}) {
		} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		} elsif ($major_version >= $min_geo_version) {
			$firefox->geo($json);
			if (my $geo3 = $firefox->geo()) {
				$latitude = $geo3->latitude();
				ok($latitude >= -90 && $latitude <= 90, "\$geo3->latitude() looks like a latitude >= -90 and <= 90:$latitude");
				$longitude = $geo3->longitude();
				ok($longitude >= -180 && $longitude <= 180, "\$geo3->longitude() looks like a longitude >= -180 and <= 180:$longitude");
				my $timezone_offset = $geo3->timezone_offset();
				ok(defined $timezone_offset, "\$geo3->timezone_offset() is the javascript timezone offset:$timezone_offset");
				my $accuracy = $geo3->accuracy();
				TODO: {
					local $TODO = ($major_version < 63) ? "\$geo3->accuracy() not available for older versions of firefox" : ($^O eq 'dragonfly') ? "\$geo3->accuracy can fail on DragonFly" : q[];
					ok(defined $accuracy && $accuracy >= 0, "\$geo3->accuracy() is a positive float (accuracy in metres):" . (defined $accuracy ? $accuracy : q[]));
				}
				my $altitude = $geo3->altitude();
				if (defined $altitude) {
					ok($altitude >= 0, "\$geo3->altitude() is a positive float (altitude in metres):$altitude");
				} else {
					ok(1, "\$geo3->altitude() is not defined");
				}
				my $altitude_accuracy = $geo3->altitude_accuracy();
				if (defined $altitude_accuracy) {
					ok($altitude_accuracy >= 0, "\$geo3->altitude_accuracy() is a positive float (altitude accuracy in metres):$altitude_accuracy");
				} else {
					ok(1, "\$geo3->altitude_accuracy() is not defined");
				}
				my $heading = $geo3->heading();
				if (defined $heading) {
					ok($heading >= 0 && $heading <= 360, "\$geo3->heading() looks like a heading >= 0 and <= 360:$latitude");
				} else {
					ok(1, "\$geo3->heading() is not defined");
				}
				my $speed = $geo3->speed();
				if (defined $speed) {
					ok($speed >= 0, "\$geo3->speed() is a positive float (speed in metres per second):$speed");
				} else {
					ok(1, "\$geo3->speed() is not defined");
				}
			} elsif (($uname eq 'cygwin') || ($uname eq 'MSWin32')) {
				diag("Location services may be disabled");
				eval {
					$firefox->dismiss_alert();
				};
			}
		}
		if ($major_version < 63) {
			diag("Not attempting to do cache operations for Firefox $major_version");
		} else {
			if ($ENV{FIREFOX_HOST}) {
			} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
				diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
			} elsif ($major_version >= $min_geo_version) {
				my $path = File::Spec->catfile(Cwd::cwd(), qw(t data elements.html));
				if ($^O eq 'cygwin') {
					$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
				}
				$firefox->go("file://$path");
				if (my $geo4 = $firefox->geo()) {
					ok($geo4->latitude() == $latitude, "\$geo4->latitude() has remained after a page load");
					ok($geo4->longitude() == $longitude, "\$geo4->longitude() has remained after a page load");
				} elsif (($uname eq 'cygwin') || ($uname eq 'MSWin32')) {
					diag("Location services may be disabled");
					eval {
						$firefox->dismiss_alert();
					};
				}
			}
			ok($firefox->go('https://github.com/login'), "\$firefox->go('https://github.com/login') succeeded");
			my $old_session_cookie = github_session_cookie($firefox);
			ok($old_session_cookie, "Found github session cookie");
			ok($firefox->go('about:blank'), "\$firefox->go('about:blank') succeeded");
			my $cookie_count = 0;
			foreach my $cookie ($firefox->cookies()) {
				$cookie_count += 1;
				diag("Should not have found cookie " . $cookie->name() . " for about:blank");
			}
			ok($cookie_count == 0, "There are no availabe cookies for about:blank");
			ok(ref $firefox->clear_cache() eq $class, "\$firefox->clear_cache() produces a $class object");
			ok($firefox->go('https://github.com/login'), "\$firefox->go('https://github.com/login') succeeded");
			my $new_session_cookie = github_session_cookie($firefox);
			ok(defined $new_session_cookie, "The session cookie was found after clearing cache");
			ok($old_session_cookie ne $new_session_cookie, "Different session cookie found after clearing everything in the cache");
			$old_session_cookie = $new_session_cookie;
			ok($firefox->go('about:blank'), "\$firefox->go('about:blank') succeeded");
			ok(ref $firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_COOKIES()) eq $class, "\$firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_COOKIES()) produces a $class object");
			ok($firefox->go('https://github.com/login'), "\$firefox->go('https://github.com/login') succeeded");
			$new_session_cookie = github_session_cookie($firefox);
			ok(defined $new_session_cookie, "The session cookie was found after clearing cache");
			ok($old_session_cookie ne $new_session_cookie, "Different session cookie found after clearing cookie cache");
			$old_session_cookie = $new_session_cookie;
			ok($firefox->go('about:blank'), "\$firefox->go('about:blank') succeeded");
			ok(ref $firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_NETWORK_CACHE()) eq $class, "\$firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_NETWORK_CACHE()) produces a $class object");
			ok($firefox->go('https://github.com/login'), "\$firefox->go('https://github.com/login') succeeded");
			$new_session_cookie = github_session_cookie($firefox);
			ok(defined $new_session_cookie, "The session cookie was found after clearing cache");
			TODO: {
				local $TODO = q[Sometimes this doesn't work for github];
				ok($old_session_cookie eq $new_session_cookie, "The same session cookie found after clearing network cache");
			}
		}
	}
	Firefox::Marionette::Cache->import(qw(:all));
	my $clear_data_service_is_ok = 1;
	eval { $firefox->check_cache_key('CLEAR_COOKIES'); } or do { $clear_data_service_is_ok = 0; chomp $@; diag("Unable to check cache values:$@"); };
	if ($clear_data_service_is_ok) {
		foreach my $name ($firefox->cache_keys()) {
			no strict;
			TODO: {
				local $TODO = ($major_version < 113 && $name !~ /^(CLEAR_COOKIES|CLEAR_NETWORK_CACHE|CLEAR_IMAGE_CACHE)$/smx) ? "Older firefox (less than 113) can have different values for Firefox::Marionette::Cache constants" : q[];
				local $TODO = $TODO || ($major_version < 128 && $name =~ /^(?:CLEAR_CREDENTIAL_MANAGER_STATE|CLEAR_COOKIE_BANNER_EXCEPTION|CLEAR_COOKIE_BANNER_EXECUTED_RECORD|CLEAR_FINGERPRINTING_PROTECTION_STATE|CLEAR_BOUNCE_TRACKING_PROTECTION_STATE|CLEAR_FORGET_ABOUT_SITE|CLEAR_STORAGE_PERMISSIONS|CLEAR_COOKIES_AND_SITE_DATA)$/) ? "Old firefox (less than 128) can have different values for Firefox::Marionette::Cache constants" : q[];
				local $TODO = $TODO || ($major_version < 129 && $name =~ /^(?:CLEAR_PERMISSIONS|CLEAR_FORGET_ABOUT_SITE)$/) ? "Old firefox (less than 129) can have different values for Firefox::Marionette::Cache constants" : q[];
				local $TODO = $TODO || ($major_version < 130 && $name =~ /^(?:CLEAR_ALL_CACHES|CLEAR_FORGET_ABOUT_SITE)$/) ? "Old firefox (less than 130) can have different values for Firefox::Marionette::Cache constants" : q[];
				local $TODO = $TODO || ($major_version < 132 && $name =~ /^(?:CLEAR_SESSION_HISTORY|CLEAR_FORGET_ABOUT_SITE)$/) ? "Old firefox (less than 132) can have different values for Firefox::Marionette::Cache constants" : q[];
				local $TODO = $TODO || ($major_version < 135 && $name =~ /^(?:CLEAR_COOKIES_AND_SITE_DATA|CLEAR_FORGET_ABOUT_SITE)$/) ? "Old firefox (less than 135) can have different values for Firefox::Marionette::Cache constants" : q[];
				my $result = $firefox->check_cache_key($name);
				ok($result == &$name(), "\$firefox->check_cache_key($name) eq Firefox::Marionette::Cache::${name} which should be $result and is " . &$name());
			}
			use strict;
		}
	}
	eval { $firefox->check_cache_key(); };
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->check_cache_key() throws an exception");
	eval { $firefox->check_cache_key("123!#"); };
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->check_cache_key(\"123!#\") throws an exception");
	ok($firefox->content(), "\$firefox->content() is called in case of previous exceptions getting the context out of sync");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	if (!grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
		diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
		skip("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version(), 4);
	}
	ok($capabilities->accept_insecure_certs(), "\$capabilities->accept_insecure_certs() is true");
	if (!$ENV{RELEASE_TESTING}) {
		skip("Skipping network tests", 3);
	}
	ok($firefox->go('about:mozilla'), 'about:mozilla has been loaded');
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
		$raw_pdf = $firefox->pdf(raw => 1, printBackground => 1, landscape => 0, page => { width => 7, height => 12 }, scale => 1);
		$pdf = PDF::API2->open_scalar($raw_pdf);
		$page = $pdf->openpage(0);
		($llx, $lly, $urx, $ury) = $page->mediabox();
		$urx = int $urx; # for darwin
		$ury = int $ury; # for darwin
		ok(((centimetres_to_points(7) == $urx) || (centimetres_to_points(7) == $urx - 1)) &&
			 ((centimetres_to_points(12) == $ury) || (centimetres_to_points(12) == $ury - 1)),
				"Correct page height of " . centimetres_to_points(12) . " (was actually $ury) and width " . centimetres_to_points(7) . " (was actually $urx)");
		$raw_pdf = $firefox->pdf(raw => 1, shrinkToFit => 1, pageRanges => [0], landscape => 1, page => { width => 7, height => 12 });
		$pdf = PDF::API2->open_scalar($raw_pdf);
		$page = $pdf->openpage(0);
		($llx, $lly, $urx, $ury) = $page->mediabox();
		$urx = int $urx; # for darwin
		$ury = int $ury; # for darwin
		if ((centimetres_to_points(12) == $urx) || (centimetres_to_points(12) == $urx - 1)) {
			ok(((centimetres_to_points(12) == $urx) || (centimetres_to_points(12) == $urx - 1)) &&
				 ((centimetres_to_points(7) == $ury) || (centimetres_to_points(7) == $ury - 1)),
					"Correct page height of " . centimetres_to_points(7) . " (was actually $ury) and width " . centimetres_to_points(12) . " (was actually $urx)");
		} else {
			# at least like this since firefox 112
			ok(((centimetres_to_points(12) == $ury) || (centimetres_to_points(12) == $ury - 1)) &&
				 ((centimetres_to_points(7) == $urx) || (centimetres_to_points(7) == $urx - 1)),
					"Correct page width of " . centimetres_to_points(7) . " (was actually $urx) and height " . centimetres_to_points(12) . " (was actually $ury)");
		}
		foreach my $paper_size ($firefox->paper_sizes()) {
			$raw_pdf = $firefox->pdf(raw => 1, size => $paper_size, page_ranges => [], print_background => 1, shrink_to_fit => 1);
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

sub github_session_cookie {
	my ($firefox) = @_;
	my $session_name = '_gh_sess';
	my $session_value;
	foreach my $cookie ($firefox->cookies()) {
		if ($cookie->name() eq $session_name) {
			$session_value = $cookie->value();
		}
	}
	return $session_value;
}

sub centimetres_to_points {
	my ($centimetres) = @_;
	my $inches = $centimetres / 2.54;
	my $points = int $inches * 72;
	return $points;
}

SKIP: {
	diag("Starting new firefox for testing logins");
	my $bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_firefox.json));
	($skip_message, $firefox) = start_firefox(0, addons => 1, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 1), bookmarks => $bookmarks_path);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 4);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	if ($major_version < 51) {
		diag("WebGL does not work and should not as version $major_version is older than 51");
	} elsif ($firefox->script(q[let c = document.createElement('canvas'); return c.getContext('webgl2') ? true : c.getContext('experimental-webgl') ? true : false;])) {
		diag("WebGL appears to be enabled in headless mode (with addons => 1)");
	} else {
		diag("WebGL appears to be disabled in headless mode (with addons => 1)");
	}
	if ($major_version >= 60) {
		ok(ref $firefox->import_bookmarks($bookmarks_path) eq $class, "\$firefox->import_bookmarks('$bookmarks_path') returns itself for chaining");
		my ($bookmark) = $firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') });
		ok($bookmark, "Retrieved bookmark from firefox export as " . $bookmark->url());
		ok($bookmark->url() eq $metacpan_uri . 'pod/Firefox::Marionette', "\$bookmark->url() is '${metacpan_uri}pod/Firefox::Marionette':" . $bookmark->url());
		ok($bookmark->date_added() == 1685610972, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->last_modified() == 1685610973, "\$bookmark->last_modified() is " . localtime $bookmark->last_modified());
		ok($bookmark->title() eq 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org', "\$bookmark->title() is 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid() eq 'utcxPgIOG05d', "\$bookmark->guid() is 'utcxPgIOG05d':" . $bookmark->guid());
		my $count = 0;
		foreach my $bookmark ($firefox->bookmarks($metacpan_uri)) {
			$count += 1;
		}
		ok($count == 2, "\$firefox->search_bookmark('$metacpan_uri') produces 2 results:$count");
		ok(ref $firefox->delete_bookmark($bookmark) eq $class, "\$firefox->delete_bookmark(\$bookmark) returns itself for chaining");
		ok(!$firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') }), "Bookmark for " . $bookmark->url() . " has been deleted");
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new('https://perlmonks.org/') });
		ok($bookmark->url() eq 'https://perlmonks.org/', "\$bookmark->url() is 'https://perlmonks.org/':" . $bookmark->url());
		ok($bookmark->date_added() == 1686364081, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->last_modified() == 1686364095, "\$bookmark->last_modified() is " . localtime $bookmark->last_modified());
		ok($bookmark->title() eq 'PerlMonks - The Monastery Gates', "\$bookmark->title() is 'PerlMonks - The Monastery Gates':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid(), "\$bookmark->guid() is " . $bookmark->guid());
		ok(!defined $bookmark->icon_url(), "\$bookmark->icon_url() is not defined");
		ok(!defined $bookmark->icon(), "\$bookmark->icon() is not defined");
		$count = 0;
		foreach my $bookmark ($firefox->bookmarks($metacpan_uri)) {
			$count += 1;
			ok($bookmark->type(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a type method:" . $bookmark->type());
			ok($bookmark->guid(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a guid method:" . $bookmark->guid());
			ok($bookmark->url(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a url method:" . $bookmark->url());
			my $title = $bookmark->title();
			$title = Encode::encode('UTF-8', $title, 1);
			ok($title, "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a title method:" . $title);
			ok($bookmark->parent_guid(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a parent_guid method:" . $bookmark->parent_guid());
		}
		ok($count == 1, "\$firefox->search_bookmark('$metacpan_uri') produces 1 result:$count");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			$count += 1;
			ok($bookmark->type(), "\$firefox->search_bookmark() returns results ($count) that have a type method:" . $bookmark->type());
			ok($bookmark->guid(), "\$firefox->search_bookmark() returns results ($count) that have a guid method:" . $bookmark->guid());
			if ($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) {
				ok($bookmark->url(), "\$firefox->search_bookmark() returns results ($count) that have a url method:" . $bookmark->url());
			}
			if (($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) || ($bookmark->type() == Firefox::Marionette::Bookmark::FOLDER())) {
				my $title = $bookmark->title();
				$title = Encode::encode('UTF-8', $title, 1);
				ok($title, "\$firefox->search_bookmark() returns results ($count) that have a title method:" . $title);
			}
			my @tags = $bookmark->tags();
			ok(scalar @tags >= 0, "\$firefox->search_bookmark() returns results ($count) that have a tag method that produces " . (scalar @tags) . " tags");
			ok($bookmark->parent_guid(), "\$firefox->search_bookmark() returns results ($count) that have a parent_guid method:" . $bookmark->parent_guid());
			if ($bookmark->parent_guid() ne Firefox::Marionette::Bookmark::ROOT()) {
				ok($firefox->delete_bookmark($bookmark), "Deleting this bookmark");
			}
		}
		my $original_guid;
		ok($count >= 7, "\$firefox->search_bookmark('$metacpan_uri') produces more than 7 results:$count");
		$bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_firefox.html));
		ok(ref $firefox->import_bookmarks($bookmarks_path) eq $class, "\$firefox->import_bookmarks('$bookmarks_path') returns itself for chaining");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			$count += 1;
			ok($bookmark->type(), "\$firefox->search_bookmark() returns results ($count) that have a type method:" . $bookmark->type());
			ok($bookmark->guid(), "\$firefox->search_bookmark() returns results ($count) that have a guid method:" . $bookmark->guid());
			ok(defined $bookmark->idx(), "\$firefox->search_bookmark() returns results ($count) that have a guid method:" . $bookmark->idx());
			if ($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) {
				ok($bookmark->url(), "\$firefox->search_bookmark() returns results ($count) that have a url method:" . $bookmark->url());
			}
			if (($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) || ($bookmark->type() == Firefox::Marionette::Bookmark::FOLDER())) {
				my $title = $bookmark->title();
				$title = Encode::encode('UTF-8', $title, 1);
				ok($title, "\$firefox->search_bookmark() returns results ($count) that have a title method:" . $title);
			}
			ok($bookmark->parent_guid(), "\$firefox->search_bookmark() returns results ($count) that have a parent_guid method:" . $bookmark->parent_guid());
		}
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') });
		ok($bookmark, "Retrieved bookmark from firefox export as " . $bookmark->url());
		ok($bookmark->url() eq $metacpan_uri . 'pod/Firefox::Marionette', "\$bookmark->url() is '${metacpan_uri}pod/Firefox::Marionette':" . $bookmark->url());
		ok(defined $bookmark->idx(), "\$bookmark->idx() is defined:" . $bookmark->idx());
		ok($bookmark->date_added() == 1685610972, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->last_modified() == 1685610973, "\$bookmark->last_modified() is " . localtime $bookmark->last_modified());
		ok($bookmark->content_type() eq 'text/x-moz-place', "\$bookmark->content_type() is 'text/x-moz-place':" . $bookmark->content_type());
		ok($bookmark->title() eq 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org', "\$bookmark->title() is 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		if (!defined $original_guid) {
			$original_guid = $bookmark->guid();
		}
		ok($bookmark->guid() eq $original_guid, "\$bookmark->guid() is '$original_guid':" . $bookmark->guid());
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "\$bookmark->icon_url() is '$metacpan_bookmark_icon_url':" . $bookmark->icon_url());
		ok($bookmark->icon() eq $metacpan_bookmark_icon, "\$bookmark->icon() is correct:" . $bookmark->icon());
		$count = 0;
		foreach my $bookmark ($firefox->bookmarks($metacpan_uri)) {
			$count += 1;
		}
		ok($count == 2, "\$firefox->search_bookmark('$metacpan_uri') produces 2 results:$count");
		ok(ref $firefox->delete_bookmark($bookmark) eq $class, "\$firefox->delete_bookmark(\$bookmark) returns itself for chaining");
		ok(!$firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') }), "Bookmark for " . $bookmark->url() . " has been deleted");
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new('https://perlmonks.org/') });
		ok($bookmark->url() eq 'https://perlmonks.org/', "\$bookmark->url() is 'https://perlmonks.org/':" . $bookmark->url());
		ok($bookmark->date_added() == 1686364081, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->last_modified() == 1686364095, "\$bookmark->last_modified() is " . localtime $bookmark->last_modified());
		ok($bookmark->title() eq 'PerlMonks - The Monastery Gates', "\$bookmark->title() is 'PerlMonks - The Monastery Gates':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid(), "\$bookmark->guid() is " . $bookmark->guid());
		ok(!defined $bookmark->icon_url(), "\$bookmark->icon_url() is not defined");
		ok(!defined $bookmark->icon(), "\$bookmark->icon() is not defined");
		$count = 0;
		foreach my $bookmark ($firefox->bookmarks($metacpan_uri)) {
			$count += 1;
			ok($bookmark->type(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a type method:" . $bookmark->type());
			ok($bookmark->guid(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a guid method:" . $bookmark->guid());
			ok($bookmark->url(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a url method:" . $bookmark->url());
			my $title = $bookmark->title();
			$title = Encode::encode('UTF-8', $title, 1);
			ok($title, "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a title method:" . $title);
			ok($bookmark->parent_guid(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a parent_guid method:" . $bookmark->parent_guid());
			ok($bookmark->icon() eq $metacpan_bookmark_icon, "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a icon method that is correct:" . $bookmark->icon());
			my $starting_regex = quotemeta 'fake-favicon-uri:https://metacpan.org';
			ok($bookmark->icon_url() =~ /^$starting_regex/smx, "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a icon_url method that look vaguely correct:" . $bookmark->icon_url());
			ok(!defined $bookmark->keyword(), "\$firefox->search_bookmark('$metacpan_uri') returns results ($count) that have a keyword method that returns undefined");
		}
		ok($count == 1, "\$firefox->search_bookmark('$metacpan_uri') produces 1 result:$count");
		my $icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADgElEQVQ4T6WTa0xbdRiHf/9259DT0pV2a7m4zo2OKTNjNo3TBNAtUbKQNigpQwOMLXHGTRN1yTAaNKCbW7yGqRnJdKibU2FkCMxZYFPi7FBhKW4tc4O2yCgUWmjp/fScHhm6TD/7fns/PL/kvTwE/7PIv/mxCoNCoOiyBKF20vFIIRVP0nFGEhYY+nea8IeYefZCdtdQbBESbnNLAYsdcT2xuYBk0G+ma+8xSUqrIMnbCMLz4LkE+EAAbF8bgvYBCxcIvpab/9sQaUDqFrsU4KzcvEm8QmNZWVabKb7XgKRnFNEL3Qi1tkKklkO+/RnIt1UAU07MfnlkLuwZNeWfvmpdCnBt2SIRrxe1qne+bEpGk/A17oXyxVcgK38W3GUrfO/UITk7DSEeg6axGTQtwsyppl7OM1qT2+nyktHqom0qQ+E5mXkvJswPQlpeC1XdYaT9M2TMfQ3+d+uQcF0HIhFkH/0OXNcn8NsGdg9yv7aQkeqii6tf/agwZu1BqPs0pE1t8MSl0KoZKDNkuDzFgfrgBWTY+5FMsJAbt2N5cQm8xw50RX/2mInD/EBYd6RdNrnrMSzLuhtM0xk4bvigVsqRr1Oi0+ZF5g/N0E2dRTwSR8rPIOfjbnjqa4KiYXs2cRk3CtqT/XBuzQNdoIfyYAug1IDiJpA2dx6iII/Yn4NgfcNgZwUE28exptuBmYYdmJq4IiPXyw3s2k8tlGePERyXgmz3fmSWmIHQWfC/PIWgVQNekEKkohC6JCDli2FVyzlMH9wzOWm7mkfsNUU/rn7ujUeig/1YOHMCTGkl7tr3FsDPg71yCmHLMdBEjOg8QXg4AHnZ01BsNWH6/X297HmnifxR9VDtCt19n8lq9mOyqhiUvhhZze2glx7Eg/nXa9Gzzo+1bgGakRlkfd2PVN9X8F/sfVz7xU+dZOxRg0KslZ5UV71kTAkUgu814GZjHY5Si+daCMI/7YZbk8Kh5hBKdzQBWcvhPf52n9/jqNB3uAN/f2K1fpM4I8eifvL5THqdHiPhMRye+xAkRVByU4lx5TKY1++C7sYEvB3H5xLjbpPuW9ulW07ccaFaXyBiVAcUGwxGUlKJ2EoF0lWZSIvzCDmGwH//DSLOaz2p0EJ9boHtvy7cNstasYrJluQ8zIKuF2Ls/Uw8ls7SaWySYQYocJ+z7ELHhjb74jrv2PgXU1mEH5MqexkAAAAASUVORK5CYII=';
		my $icon_url = 'https://duckduckgo.com/favicon.ico';
		$count = 0;
		foreach my $bookmark ($firefox->bookmarks('https://duckduckgo.com')) {
			$count += 1;
			ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a type that is Firefox::Marionette::Bookmark::BOOKMARK()::" . $bookmark->type());
			ok($bookmark->guid(), "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a guid method:" . $bookmark->guid());
			ok(ref $bookmark->url() eq 'URI::URL', "\$bookmark->url() returns a URI::URL object");
			ok($bookmark->url() eq 'https://duckduckgo.com/?va=v&t=ha&q=perl+%F0%9F%90%AB&ia=web', "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a url that is 'https://duckduckgo.com/?va=v&t=ha&q=perl+%F0%9F%90%AB&ia=web':" . $bookmark->url());
			my $title = $bookmark->title();
			$title = Encode::encode('UTF-8', $title, 1);
			ok($title eq 'perl 🐫 at DuckDuckGo', "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a title method that is 'perl 🐫 at DuckDuckGo':" . $title);
			ok($bookmark->date_added() == 1685670771, "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a date_added method that is " . localtime $bookmark->date_added());
			ok($bookmark->last_modified() == 1685670772, "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a last_modified method that is " . localtime $bookmark->last_modified());
			ok($bookmark->parent_guid(), "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a parent_guid method:" . $bookmark->parent_guid());
			ok(ref $bookmark->icon_url() eq 'URI::URL', "\$bookmark->icon_url() returns a URI::URL object");
			ok($bookmark->icon_url() eq $icon_url, "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a icon_url method that is '$icon_url':" . $bookmark->icon_url());
			ok(ref $bookmark->icon() eq 'URI::data', "\$bookmark->icon() returns a URI::data object");
			ok($bookmark->icon() eq $icon, "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a icon method that is :" . $bookmark->icon());
			my $keyword = $bookmark->keyword();
			$keyword = Encode::encode('UTF-8', $keyword, 1);
			ok($keyword eq '🐫', "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a keyword method:" . $keyword);
			my $tag_count = 0;
			foreach my $tag ($bookmark->tags()) {
				$tag_count += 1;
				$tag = Encode::encode('UTF-8', $tag, 1);
				ok($tag =~ /^(🐫|ddg|UTF8|perl)$/smx, "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a tag method with one of '🐫', 'ddg', 'UTF8' or 'perl':" . $tag);
			}
			ok($tag_count == 4, "\$firefox->search_bookmark('https://duckduckgo.com') returns results ($count) that have a tag method with 4 tags:" . $tag_count);
		}
		ok($count == 1, "\$firefox->search_bookmark('https://duckduckgo.com') produces 1 result:$count");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			$count += 1;
			if ($bookmark->parent_guid() ne Firefox::Marionette::Bookmark::ROOT()) {
				ok($firefox->delete_bookmark($bookmark), "Deleting this bookmark:" . $bookmark->guid());
			}
		}
		$bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_firefox.json));
		ok(ref $firefox->import_bookmarks($bookmarks_path) eq $class, "\$firefox->import_bookmarks('$bookmarks_path') returns itself for chaining");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			$count += 1;
		}
		my $original_count = $count;
		my $metacpan_pod_guid = 'utcxPgIOG05d';
		ok($firefox->delete_bookmark(Firefox::Marionette::Bookmark->new(guid => $metacpan_pod_guid)), "Deleting this bookmark:" . $metacpan_pod_guid);
		ok(ref $firefox->import_bookmarks($bookmarks_path) eq $class, "\$firefox->import_bookmarks('$bookmarks_path') returns itself for chaining");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			if (my $title = $bookmark->title()) {
				$title = Encode::encode('UTF-8', $title, 1);
				ok($title, "Bookmark $count is " . $title);
			} else {
				ok($bookmark->guid(), "Bookmark $count is " . $bookmark->guid() . " with type " . $bookmark->type() . " with parent " . $bookmark->parent_guid());
			}
			$count += 1;
		}
		ok($original_count == $count, "Same number of bookmarks after importing the same json file:$original_count == $count");
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') });
		ok($bookmark->url() eq $metacpan_uri . 'pod/Firefox::Marionette', "\$bookmark->url() is '${metacpan_uri}pod/Firefox::Marionette':" . $bookmark->url());
		ok(defined $bookmark->idx(), "\$bookmark->idx() is defined:" . $bookmark->idx());
		ok($bookmark->date_added() == 1685610972, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->last_modified() == 1685610973, "\$bookmark->last_modified() is " . localtime $bookmark->last_modified());
		ok($bookmark->content_type() eq 'text/x-moz-place', "\$bookmark->content_type() is 'text/x-moz-place':" . $bookmark->content_type());
		ok($bookmark->title() eq 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org', "\$bookmark->title() is 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid() eq $metacpan_pod_guid, "\$bookmark->guid() is '$metacpan_pod_guid':" . $bookmark->guid());
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "\$bookmark->icon_url() is '$metacpan_bookmark_icon_url':" . $bookmark->icon_url());
		ok($bookmark->icon() eq $metacpan_bookmark_icon, "\$bookmark->icon() is correct:" . $bookmark->icon());
		$bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_firefox.html));
		ok(ref $firefox->import_bookmarks($bookmarks_path) eq $class, "\$firefox->import_bookmarks('$bookmarks_path') returns itself for chaining");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			if (my $title = $bookmark->title()) {
				$title = Encode::encode('UTF-8', $title, 1);
				ok($title, "Bookmark $count is " . $title);
			} else {
				ok($bookmark->guid(), "Bookmark $count is " . $bookmark->guid() . " with type " . $bookmark->type() . " with parent " . $bookmark->parent_guid());
			}
			$count += 1;
		}
		ok($original_count == $count, "Same number of bookmarks after importing the same json file:$original_count == $count");
		($bookmark) = $firefox->bookmarks({ url => URI::URL->new($metacpan_uri . 'pod/Firefox::Marionette') });
		ok($bookmark->url() eq $metacpan_uri . 'pod/Firefox::Marionette', "\$bookmark->url() is '${metacpan_uri}pod/Firefox::Marionette':" . $bookmark->url());
		ok(defined $bookmark->idx(), "\$bookmark->idx() is defined:" . $bookmark->idx());
		ok($bookmark->date_added() == 1685610972, "\$bookmark->date_added() is " . localtime $bookmark->date_added());
		ok($bookmark->last_modified() == 1685610973, "\$bookmark->last_modified() is " . localtime $bookmark->last_modified());
		ok($bookmark->content_type() eq 'text/x-moz-place', "\$bookmark->content_type() is 'text/x-moz-place':" . $bookmark->content_type());
		ok($bookmark->title() eq 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org', "\$bookmark->title() is 'Firefox::Marionette - Automate the Firefox browser with the Marionette protocol - metacpan.org':" . $bookmark->title());
		ok($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK(), "\$bookmark->type() is Firefox::Marionette::Bookmark::BOOKMARK():" . $bookmark->type());
		ok($bookmark->parent_guid(), "\$bookmark->parent_guid() is " . $bookmark->parent_guid());
		ok($bookmark->guid() eq $metacpan_pod_guid, "\$bookmark->guid() is '$metacpan_pod_guid':" . $bookmark->guid());
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "\$bookmark->icon_url() is '$metacpan_bookmark_icon_url':" . $bookmark->icon_url());
		ok($bookmark->icon() eq $metacpan_bookmark_icon, "\$bookmark->icon() is correct:" . $bookmark->icon());
		$bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_firefox.html));
		ok(ref $firefox->import_bookmarks($bookmarks_path) eq $class, "\$firefox->import_bookmarks('$bookmarks_path') returns itself for chaining");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			if (my $title = $bookmark->title()) {
				my $title = $bookmark->title();
				$title = Encode::encode('UTF-8', $title, 1);
				ok($title, "Bookmark $count is " . $title);
			} else {
				ok($bookmark->guid(), "Bookmark $count is " . $bookmark->guid() . " with type " . $bookmark->type() . " with parent " . $bookmark->parent_guid());
			}
			$count += 1;
		}
		ok($original_count == $count, "Same number of bookmarks after importing the same json file:$original_count == $count");
		$count = 0;
		foreach my $bookmark (reverse $firefox->bookmarks()) {
			$count += 1;
			ok($bookmark->type(), "\$firefox->search_bookmark() returns results ($count) that have a type method:" . $bookmark->type());
			ok($bookmark->guid(), "\$firefox->search_bookmark() returns results ($count) that have a guid method:" . $bookmark->guid());
			if ($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) {
				ok($bookmark->url(), "\$firefox->search_bookmark() returns results ($count) that have a url method:" . $bookmark->url());
			}
			ok($bookmark->content_type(), "\$firefox->search_bookmark() returns results ($count) that have a content_type method:" . $bookmark->content_type());
			if (($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) || ($bookmark->type() == Firefox::Marionette::Bookmark::FOLDER())) {
				my $title = $bookmark->title();
				$title = Encode::encode('UTF-8', $title, 1);
				ok($title, "\$firefox->search_bookmark() returns results ($count) that have a title method:" . $title);
			}
			if ($bookmark->type() == Firefox::Marionette::Bookmark::BOOKMARK()) {
				if (defined $bookmark->icon_url()) {
					ok($bookmark->icon_url(), "\$firefox->search_bookmark() returns results ($count) that have a icon_url method:" . $bookmark->icon_url());
				}
				if (defined $bookmark->icon()) {
					ok($bookmark->icon(), "\$firefox->search_bookmark() returns results ($count) that have a icon method that is :" . $bookmark->icon());
				}
			}
			ok($bookmark->parent_guid(), "\$firefox->search_bookmark() returns results ($count) that have a parent_guid method:" . $bookmark->parent_guid());
			if ($bookmark->parent_guid() ne Firefox::Marionette::Bookmark::ROOT()) {
				ok($firefox->delete_bookmark($bookmark), "Deleting this bookmark");
			}
		}
		ok($count >= 7, "\$firefox->search_bookmark('$metacpan_uri') produces more than 7 results:$count");
		$bookmark = Firefox::Marionette::Bookmark->new( parent_guid => Firefox::Marionette::Bookmark::MOBILE(), url => URI::URL->new($metacpan_uri), icon => URI::data->new($metacpan_bookmark_icon), icon_url => URI::URL->new($metacpan_bookmark_icon_url) );
		ok($bookmark, "Firefox::Marionette::Bookmark->new() produces a new bookmark");
		ok(ref $bookmark->url() eq 'URI::URL', "Firefox::Marionette::Bookmark->new()->url() returns a URI::URL object");
		ok($bookmark->url() eq $metacpan_uri, "Firefox::Marionette::Bookmark->new()->url() returns '$metacpan_uri' as a string");
		ok(ref $bookmark->icon_url() eq 'URI::URL', "Firefox::Marionette::Bookmark->new()->icon_url() returns a URI::URL object");
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "Firefox::Marionette::Bookmark->new()->icon_url() returns '$metacpan_bookmark_icon_url' as a string");
		ok(ref $bookmark->icon() eq 'URI::data', "Firefox::Marionette::Bookmark->new()->icon() returns a URI::data object");
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "Firefox::Marionette::Bookmark->new()->icon() returns '$metacpan_bookmark_icon' as a string");
		my $bookmark_name = "Meta Cpan for the win!";
		$bookmark = Firefox::Marionette::Bookmark->new( title => $bookmark_name, url => $metacpan_uri, icon => $metacpan_bookmark_icon, icon_url => $metacpan_bookmark_icon_url );
		ok($bookmark, "Firefox::Marionette::Bookmark->new() produces a new bookmark");
		ok($bookmark->title() eq $bookmark_name, "Firefox::Marionette::Bookmark->new()->title() returns '$bookmark_name' as a string");
		ok(ref $bookmark->url() eq 'URI::URL', "Firefox::Marionette::Bookmark->new()->url() returns a URI::URL object");
		ok($bookmark->url() eq $metacpan_uri, "Firefox::Marionette::Bookmark->new()->url() returns '$metacpan_uri' as a string");
		ok(ref $bookmark->icon_url() eq 'URI::URL', "Firefox::Marionette::Bookmark->new()->icon_url() returns a URI::URL object");
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "Firefox::Marionette::Bookmark->new()->icon_url() returns '$metacpan_bookmark_icon_url' as a string");
		ok(ref $bookmark->icon() eq 'URI::data', "Firefox::Marionette::Bookmark->new()->icon() returns a URI::data object");
		ok($bookmark->icon_url() eq $metacpan_bookmark_icon_url, "Firefox::Marionette::Bookmark->new()->icon() returns '$metacpan_bookmark_icon' as a string");
		ok($bookmark->type() eq Firefox::Marionette::Bookmark::BOOKMARK(), "Firefox::Marionette::Bookmark->new()->type() returns a bookmark if a url and title is supplied");
		ok($bookmark->content_type() eq 'text/x-moz-place', "Firefox::Marionette::Bookmark->new()->content_type() returns 'text/x-moz-place' if a url and title is supplied");
		my $folder_name = "Samples";
		$bookmark = Firefox::Marionette::Bookmark->new( title => $folder_name );
		ok($bookmark->title() eq $folder_name, "Firefox::Marionette::Bookmark->new()->title() returns the supplied title");
		ok($bookmark->type() eq Firefox::Marionette::Bookmark::FOLDER(), "Firefox::Marionette::Bookmark->new()->type() returns a folder if a title is supplied, with no url");
		ok($bookmark->content_type() eq 'text/x-moz-place-container', "Firefox::Marionette::Bookmark->new()->content_type() returns 'text/x-moz-place-container' if a title is supplied, with no url");
		$bookmark = Firefox::Marionette::Bookmark->new( type => 4, index => undef );
		$bookmark = Firefox::Marionette::Bookmark->new( type => 4, index => undef );
		ok($bookmark, "Firefox::Marionette::Bookmark->new() produces a new bookmark with an unknown type of 4");
		ok(!defined $bookmark->content_type(), "If a bookmark does not have a known type, it does not have a content type");
		ok(JSON->new()->convert_blessed()->encode($bookmark), "Bookmark with bad parameters can be turned into JSON:" . JSON->new()->convert_blessed()->encode($bookmark));
		$bookmarks_path = File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_truncated.html));
		eval {
			$firefox->import_bookmarks($bookmarks_path);
		};
		chomp $@;
		ok($@, "Exception correctly thrown when trying to import a truncated bookmarks file of $bookmarks_path:$@");
	}
	my $bookmark = Firefox::Marionette::Bookmark->new();
	ok(!defined $bookmark->type(), "There is no defined type if a bookmark is created with no parameters");
	ok(!defined $bookmark->content_type(), "There is no defined content_type if a bookmark is created with no parameters");
	Firefox::Marionette::Bookmark->import(qw(:all));
	foreach my $name (qw(BOOKMARK FOLDER SEPARATOR)) {
		my $result = eval "return Firefox::Marionette::Bookmark::$name();";
		no strict;
		ok($result == &$name(), "Firefox::Marionette::Bookmark::$name() == $name() after Firefox::Marionette::Bookmark->import(:all)");
		use strict;
	}
	foreach my $name (qw(MENU ROOT TOOLBAR TAGS UNFILED)) {
		my $result = eval "return Firefox::Marionette::Bookmark::$name();";
		no strict;
		ok($result eq &$name(), "Firefox::Marionette::Bookmark::$name() eq $name() after Firefox::Marionette::Bookmark->import(:all)");
		use strict;
	}
	my $new_max_url_length = 4321;
	my $original_max_url_length = $firefox->get_pref('browser.history.maxStateObjectSize');
	ok($original_max_url_length =~ /^\d+$/smx, "Retrieved browser.history.maxStateObjectSize as a number '$original_max_url_length'");
	ok(ref $firefox->set_pref('browser.history.maxStateObjectSize', $new_max_url_length) eq $class, "\$firefox->set_pref correctly returns itself for chaining and set 'browser.history.maxStateObjectSize' to '$new_max_url_length'");
	my $max_url_length = $firefox->get_pref('browser.history.maxStateObjectSize');
	ok($max_url_length == $new_max_url_length, "Retrieved browser.history.maxStateObjectSize which was equal to the previous setting of '$new_max_url_length'");
	ok(ref $firefox->set_pref('browser.history.maxStateObjectSize', $original_max_url_length) eq $class, "\$firefox->set_pref correctly returns itself for chaining and set 'browser.history.maxStateObjectSize' to the original '$original_max_url_length'");
	$max_url_length = $firefox->get_pref('browser.history.maxStateObjectSize');
	ok($max_url_length == $original_max_url_length, "Retrieved browser.history.maxStateObjectSize as a number '$max_url_length' which was equal to the original setting of '$original_max_url_length'");
	my $original_use_system_colours = $firefox->get_pref('browser.display.use_system_colors');
	ok($original_use_system_colours =~ /^[01]$/smx, "Retrieved browser.display.use_system_colors as a boolean '$original_use_system_colours', and set it as true");
	ok(ref $firefox->set_pref('browser.display.use_system_colors', \1) eq $class, "\$firefox->set_pref correctly returns itself for chaining and set 'browser.display.use_system_colors' to 'true'");;
	my $use_system_colours = $firefox->get_pref('browser.display.use_system_colors');
	ok($use_system_colours, "Retrieved browser.display.use_system_colors as true '$use_system_colours'");
	ok(ref $firefox->set_pref('browser.display.use_system_colors', \0) eq $class, "\$firefox->set_pref correctly returns itself for chaining and set 'browser.display.use_system_colors' to 'false'");;
	$use_system_colours = $firefox->get_pref('browser.display.use_system_colors');
	ok(!$use_system_colours, "Retrieved browser.display.use_system_colors as false '$use_system_colours'");
	ok(ref $firefox->clear_pref('browser.display.use_system_colors', \0) eq $class, "\$firefox->clear_pref correctly returns itself for chaining and cleared 'browser.display.use_system_colors'");
	$use_system_colours = $firefox->get_pref('browser.display.use_system_colors');
	ok($use_system_colours == $original_use_system_colours, "Retrieved original browser.display.use_system_colors as a boolean '$use_system_colours'");
	ok(!defined $firefox->get_pref('browser.no_such_key'), "Returned undef when querying for a non-existant key of 'browser.no_such_key'");
	my $new_value = "Can't be real:$$";
	ok(ref $firefox->set_pref('browser.no_such_key', $new_value) eq $class, "\$firefox->set_pref correctly returns itself for chaining and set 'browser.no_such_key' to '$new_value'");
	ok($firefox->get_pref('browser.no_such_key') eq $new_value, "Returned browser.no_such_key as a string '$new_value'");
	my $new_active_colour = '#FFFFFF';
	my $original_active_colour = $firefox->get_pref('browser.active_color');
	ok($original_active_colour =~ /^[#][[:xdigit:]]{6}$/smx, "Retrieved browser.active_color as a string '$original_active_colour'");
	my $active_colour = $firefox->get_pref('browser.active_color');
	ok($active_colour eq $original_active_colour, "Retrieved browser.active_color as a string '$active_colour' which was equal to the original setting of '$original_active_colour'");
	ok(ref $firefox->set_pref('browser.active_color', $new_active_colour) eq $class, "\$firefox->set_pref correctly returns itself for chaining and set 'browser.active_color' to '$new_active_colour'");;
	$active_colour = $firefox->get_pref('browser.active_color');
	ok($active_colour eq $new_active_colour, "Retrieved browser.active_color as a string '$active_colour' which was equal to the new setting of '$new_active_colour'");
	ok(ref $firefox->clear_pref('browser.active_color') eq $class, "\$firefox->clear_pref correctly returns itself for chaining and cleared 'browser.active_color'");;
	$active_colour = $firefox->get_pref('browser.active_color');
	ok($active_colour eq $original_active_colour, "Retrieved browser.active_color as a string '$active_colour' which was equal to the original string of '$original_active_colour'");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 2);
	}
	if (!$ENV{RELEASE_TESTING}) {
		skip("Skipping network tests", 2);
	}
	if (grep /^accept_insecure_certs$/, $capabilities->enumerate()) {
		ok(!$capabilities->accept_insecure_certs(), "\$capabilities->accept_insecure_certs() is false");
		if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
			diag("insecure cert test is not supported for remote hosts");
		} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
			diag("insecure cert test is not supported for remote hosts");
		} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
			my $ip_address = '127.0.0.1';
			my $daemon = IO::Socket::SSL->new(
				LocalAddr => $ip_address,
				LocalPort => 0,
				Listen => 20,
				SSL_cert_file => $ca_cert_handle->filename(),
				SSL_key_file => $ca_private_key_handle->filename(),
			);
			my $url = "https://$ip_address:" . $daemon->sockport();
			if (my $pid = fork) {
				wait_for_server_on($daemon, $url, $pid);
				eval { $firefox->go(URI->new($url)) };
				my $exception = "$@";
				chomp $exception;
				ok(ref $@ eq 'Firefox::Marionette::Exception::InsecureCertificate', $url . " threw an exception:$exception");
				while(kill 0, $pid) {
					kill $signals_by_name{TERM}, $pid;
					sleep 1;
					waitpid $pid, POSIX::WNOHANG();
				}
			} elsif (defined $pid) {
				eval {
					local $SIG{ALRM} = sub { die "alarm during insecure cert test\n" };
					alarm 40;
					$0 = "[Test insecure cert test for " . getppid . "]";
					diag("Accepting connections on $url for $0");
					foreach ((1 .. 3)) {
						my $connection = $daemon->accept();
					}
					exit 0;
				};
				chomp $@;
				diag("insecure cert test server failed:$@");
				exit 1;
			} else {
				diag("insecure cert test fork failed:$@");
			}
		} else {
			diag("No forking available for $^O");
		}
	} else {
		diag("\$capabilities->accept_insecure_certs is not supported for " . $capabilities->browser_version());
	}
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 2);
	}
	my $profile_directory = $firefox->profile_directory();
	ok($profile_directory, "\$firefox->profile_directory() returns $profile_directory");
	my $possible_logins_path = File::Spec->catfile($profile_directory, 'logins.json');
	ok(!-e $possible_logins_path, "There is no logins.json file yet");
	eval { $firefox->fill_login() };
	ok(ref $@ eq 'Firefox::Marionette::Exception', "Unable to fill in form when no form is present:$@");
	my $cant_load_github;
	my $result;
	eval {
		$result = $firefox->go('https://github.com/login');
	};
	if ($@) {
		$cant_load_github = 1;
		diag("\$firefox->go('https://github.com/login') threw an exception:$@");
	} else {
		ok($result, "\$firefox loads https://github.com/login");
	}
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 2);
	}
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	my $now = time;
	my $current_year = (localtime($now))[6];
	my $pause_login = Firefox::Marionette::Login->new(host => 'https://pause.perl.org', user => 'DDICK', password => 'qwerty', realm => 'PAUSE', user_fieldname => undef);
	ok($firefox->add_login($pause_login), "\$firefox->add_login() copes with a http auth login");;
	foreach my $login ($firefox->logins()) {
		ok($login->host() eq 'https://pause.perl.org', "\$login->host() eq 'https://pause.perl.org'");
		ok($login->user() eq 'DDICK', "\$login->user() eq 'DDICK'");
		ok($login->password() eq 'qwerty', "\$login->password() eq 'qwerty'");
		ok($login->realm() eq 'PAUSE', "\$login->realm() eq 'PAUSE'");
		ok(!defined $login->user_field(), "\$login->user_field() is undefined");
		ok(!defined $login->password_field(), "\$login->password_field() is undefined");
		ok(!defined $login->origin(), "\$login->origin() is undefined");
		if ((defined $login->guid()) || ($major_version >= 59)) {
			ok($login->guid() =~ /^[{]$guid_regex[}]$/smx, "\$login->guid() is a UUID");
		}
		if ((defined $login->creation_time()) || ($major_version >= 59)) {
			my $creation_year = (localtime($login->creation_time()))[6];
			ok((($creation_year == $current_year) || ($creation_year == $current_year + 1)), "\$login->creation_time() returns a time with the correct year");
		}
		if ((defined $login->last_used_time()) || ($major_version >= 59)) {
			my $last_used_year = (localtime($login->last_used_time()))[6];
			ok((($last_used_year == $current_year) || ($last_used_year == $current_year + 1)), "\$login->last_used_time() returns a time with the correct year");
		}
		if ((defined $login->password_changed_time()) || ($major_version >= 59)) {
			my $password_changed_year = (localtime($login->password_changed_time()))[6];
			ok((($password_changed_year == $current_year) || ($password_changed_year == $current_year + 1)), "\$login->password_changed_time() returns a time with the correct year");
		}
		if ((defined $login->times_used()) || ($major_version >= 59)) {
			ok($login->times_used() =~ /^\d+$/smx, "\$login->times_used() is a number");
		}
	}
	ok(scalar $firefox->logins() == 1, "\$firefox->logins() shows the correct number (1) of records");
	my $github_login = Firefox::Marionette::Login->new(host => 'https://github.com', user => 'ddick@cpan.org', password => 'qwerty', user_field => 'login', password_field => 'password');
	ok($firefox->add_login($github_login), "\$firefox->add_login() copes with a form based login");
	ok($firefox->delete_login($pause_login), "\$firefox->delete_login() removes the http auth login");
	foreach my $login ($firefox->logins()) {
		ok($login->host() eq 'https://github.com', "\$login->host() eq 'https://github.com':" . $login->host());
		ok($login->user() eq 'ddick@cpan.org', "\$login->user() eq 'ddick\@cpan.org':" . $login->user());
		ok($login->password() eq 'qwerty', "\$login->password() eq 'qwerty':" . $login->password());
		ok(!defined $login->realm(), "\$login->realm() is undefined");
		ok($login->user_field() eq 'login', "\$login->user_field() eq 'login':" . $login->user_field());
		ok($login->password_field() eq 'password', "\$login->password_field() eq 'password':" . $login->password_field());
		ok(!defined $login->origin(), "\$login->origin() is not defined");
		if ((defined $login->guid()) || ($major_version >= 59)) {
			ok($login->guid() =~ /^[{]$guid_regex[}]$/smx, "\$login->guid() is a UUID");
		}
		if ((defined $login->creation_time()) || ($major_version >= 59)) {
			my $creation_year = (localtime($login->creation_time()))[6];
			ok((($creation_year == $current_year) || ($creation_year == $current_year + 1)), "\$login->creation_time() returns a time with the correct year");
		}
		if ((defined $login->last_used_time()) || ($major_version >= 59)) {
			my $last_used_year = (localtime($login->last_used_time()))[6];
			ok((($last_used_year == $current_year) || ($last_used_year == $current_year + 1)), "\$login->last_used_time() returns a time with the correct year");
		}
		if ((defined $login->password_changed_time()) || ($major_version >= 59)) {
			my $password_changed_year = (localtime($login->password_changed_time()))[6];
			ok((($password_changed_year == $current_year) || ($password_changed_year == $current_year + 1)), "\$login->password_changed_time() returns a time with the correct year");
		}
		if ((defined $login->times_used()) || ($major_version >= 59)) {
			ok($login->times_used() =~ /^\d+$/smx, "\$login->times_used() is a number");
		}
	}
	my $perlmonks_login = Firefox::Marionette::Login->new(host => 'https://www.perlmonks.org', origin => 'https://www.perlmonks.org', user => 'ddick', password => 'qwerty', user_field => 'user', password_field => 'passwd', creation_time => $now - 20, last_used_time => $now - 10, password_changed_time => $now, password_changed_in_ms => $now * 1000 - 15, times_used => 50);
	ok($firefox->add_login($perlmonks_login), "\$firefox->add_login() copes with another form based login");
	ok($firefox->delete_login($github_login), "\$firefox->delete_login() removes the original form based login");
	foreach my $login ($firefox->logins()) {
		ok($login->host() eq 'https://www.perlmonks.org', "\$login->host() eq 'https://www.perlmonks.org':" . $login->host());
		ok($login->user() eq 'ddick', "\$login->user() eq 'ddick':" . $login->user());
		ok($login->password() eq 'qwerty', "\$login->password() eq 'qwerty':" . $login->password());
		ok(!defined $login->realm(), "\$login->realm() is undefined");
		ok($login->user_field() eq 'user', "\$login->user_field() eq 'user':" . $login->user_field());
		ok($login->password_field() eq 'passwd', "\$login->password_field() eq 'passwd':" . $login->password_field());
		ok($login->origin() eq 'https://www.perlmonks.org', "\$login->origin() eq 'https://www.perlmonks.org':" . $login->host());
		if ((defined $login->guid()) || ($major_version >= 59)) {
			ok($login->guid() =~ /^[{]$guid_regex[}]$/smx, "\$login->guid() is a UUID");
		}
		if ((defined $login->creation_time()) || ($major_version >= 59)) {
			ok($login->creation_time() == $now - 20, "\$login->last_used_time() returns the assigned time:" . localtime $login->creation_time());
		}
		if ((defined $login->last_used_time()) || ($major_version >= 59)) {
			ok($login->last_used_time() == $now - 10, "\$login->last_used_time() returns the assigned time:" . localtime $login->last_used_time());
		}
		if ((defined $login->password_changed_in_ms()) || ($major_version >= 59)) {
			my $password_changed_year = (localtime($login->password_changed_time()))[6];
			ok($password_changed_year == $current_year, "\$login->password_changed_time() returns a time with the correct year");
			ok($login->password_changed_in_ms() == $now * 1000 - 15, "\$login->password_changed_time_in_ms() returns the correct number of milliseconds");
		}
		if ((defined $login->times_used()) || ($major_version >= 59)) {
			ok($login->times_used() == 50, "\$login->times_used() is the assigned number");
		}
	}
	ok($firefox->add_login($github_login), "\$firefox->add_login() copes re-adding the original form based login");
	ok(!$firefox->pwd_mgr_needs_login(), "\$firefox->pwd_mgr_needs_login() returns false");
	my @charset = ( 'A' .. 'Z', 'a' .. 'z', 0..9 );
	my $lock_password;
	for(1 .. 50) {
		$lock_password .= $charset[rand scalar @charset];
	}
	eval {
		$firefox->pwd_mgr_lock();
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->pwd_mgr_lock() throws an exception when no password is supplied:" . ref $@);
	ok($firefox->pwd_mgr_lock($lock_password), "\$firefox->pwd_mgr_lock() sets the primary password");
	ok($firefox->pwd_mgr_logout(), "\$firefox->pwd_mgr_logout() logs out");
	ok($firefox->pwd_mgr_needs_login(), "\$firefox->pwd_mgr_needs_login() returns true");
	my $wrong_password = substr $lock_password, 0, 10;
	eval {
		$firefox->pwd_mgr_login($wrong_password);
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->pwd_mgr_login() throws an exception when the wrong password is supplied:" . ref $@);
	eval {
		$firefox->pwd_mgr_login();
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->pwd_mgr_login() throws an exception when no password is supplied:" . ref $@);
	ok($firefox->pwd_mgr_login($lock_password), "\$firefox->pwd_mgr_login() logs in");
	ok(!$firefox->pwd_mgr_needs_login(), "\$firefox->pwd_mgr_needs_login() returns false");
	ok($firefox->add_login($pause_login), "\$firefox->add_login() copes with a http auth login");;
	if (!$cant_load_github) {
		ok($firefox->fill_login(), "\$firefox->fill_login() works correctly");
	}
	ok($firefox->delete_login($github_login), "\$firefox->delete_login() removes the original form based login");
	ok($firefox->add_login(host => 'https://github.com', user => 'ddick@cpan.org', password => 'qwerty', user_field => 'login', password_field => 'password', origin => 'https://github.com'), "\$firefox->add_login() copes with a driectly specified form based login");
	if (!$cant_load_github) {
		ok($firefox->fill_login(), "\$firefox->fill_login() works correctly");
	}
	ok(scalar $firefox->logins() == 3, "\$firefox->logins() shows the correct number (3) of records");
	ok($firefox->delete_logins(), "\$firefox->delete_logins() works");
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	ok($firefox->add_login(host => 'https://github.com', user => 'ddick@cpan.org', password => 'qwerty', user_field => 'login', password_field => 'password', origin => 'https://example.com'), "\$firefox->add_login() copes with a driectly specified form based login with an incorrect origin");
	eval {
		$firefox->fill_login();
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->fill_logins() throws an exception when it fails to fill the form b/c of the wrong origin:" . ref $@);
	ok($firefox->delete_logins(), "\$firefox->delete_logins() works");
	my $github_login_with_wrong_user_field = Firefox::Marionette::Login->new(host => 'https://github.com', user => 'ddick@cpan.org', password => 'qwerty', user_field => 'nopewrong', password_field => 'password');
	ok($firefox->add_login($github_login_with_wrong_user_field), "\$firefox->add_login() copes with a form based login with the incorrect user_field");
	eval {
		$firefox->fill_login();
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->fill_logins() throws an exception when it fails to fill the form b/c of the wrong user_field:" . ref $@);
	ok($firefox->delete_login($github_login_with_wrong_user_field), "\$firefox->delete_login() removes the form based login with the incorrect user_field");
	my $github_login_with_wrong_password_field = Firefox::Marionette::Login->new(host => 'https://github.com', user => 'ddick@cpan.org', password => 'qwerty', user_field => 'login', password_field => 'defintelyincorrect');
	ok($firefox->add_login($github_login_with_wrong_password_field), "\$firefox->add_login() copes with a form based login with the incorrect password_field");
	eval {
		$firefox->fill_login();
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->fill_logins() throws an exception when it fails to fill the form b/c of the wrong password_field:" . ref $@);
	ok($firefox->delete_login($github_login_with_wrong_password_field), "\$firefox->delete_login() removes the form based login with the incorrect user_field");
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	ok($firefox->add_login(host => 'https://www.perlmonks.org', origin => 'https://www.perlmonks.org', user => 'ddick', password => 'qwerty', user_field => 'user', password_field => 'passwd', creation_time => $now - 20, last_used_time => $now - 10, password_changed_time => $now, password_changed_in_ms => $now * 1000 - 15, times_used => 50), "\$firefox->add_login() copes with a form based login passed directly to it");
	foreach my $login ($firefox->logins()) {
		ok($login->host() eq 'https://www.perlmonks.org', "\$login->host() eq 'https://www.perlmonks.org':" . $login->host());
		ok($login->user() eq 'ddick', "\$login->user() eq 'ddick':" . $login->user());
		ok($login->password() eq 'qwerty', "\$login->password() eq 'qwerty':" . $login->password());
		ok(!defined $login->realm(), "\$login->realm() is undefined");
		ok($login->user_field() eq 'user', "\$login->user_field() eq 'user':" . $login->user_field());
		ok($login->password_field() eq 'passwd', "\$login->password_field() eq 'passwd':" . $login->password_field());
		ok($login->origin() eq 'https://www.perlmonks.org', "\$login->origin() eq 'https://www.perlmonks.org':" . $login->host());
		if ((defined $login->guid()) || ($major_version >= 59)) {
			ok($login->guid() =~ /^[{]$guid_regex[}]$/smx, "\$login->guid() is a UUID");
		}
		if ((defined $login->creation_time()) || ($major_version >= 59)) {
			ok($login->creation_time() == $now - 20, "\$login->last_used_time() returns the assigned time:" . localtime $login->creation_time());
		}
		if ((defined $login->last_used_time()) || ($major_version >= 59)) {
			ok($login->last_used_time() == $now - 10, "\$login->last_used_time() returns the assigned time:" . localtime $login->last_used_time());
		}
		if ((defined $login->password_changed_in_ms()) || ($major_version >= 59)) {
			my $password_changed_year = (localtime($login->password_changed_time()))[6];
			ok($password_changed_year == $current_year, "\$login->password_changed_time() returns a time with the correct year");
			ok($login->password_changed_in_ms() == $now * 1000 - 15, "\$login->password_changed_time_in_ms() returns the correct number of milliseconds");
		}
		if ((defined $login->times_used()) || ($major_version >= 59)) {
			ok($login->times_used() == 50, "\$login->times_used() is the assigned number");
		}
		ok($firefox->delete_login($login), "\$firefox->delete_login() removes the form based login passed directly");
	}
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	foreach my $path (qw(t/data/1Passwordv7.csv t/data/bitwarden_export_org.csv t/data/keepass.csv t/data/last_pass_example.csv t/data/keepassxs.csv)) {
		my $handle = FileHandle->new($path, Fcntl::O_RDONLY()) or die "Failed to open $path:$!";
		my @logins;
		my $encoded_username = '!"§$%&/()=?`´²³{[]}\\';
		my $display_username = $encoded_username;
		my $utf8_username = Encode::decode('UTF-8', $encoded_username, 1);
		my $found_utf8_user;
		foreach my $login (Firefox::Marionette->logins_from_csv($handle)) {
			if ($path eq 't/data/keepassxs.csv') {
				if ($login->user() eq $utf8_username) {
					$found_utf8_user = 1;
					my $encoded_password = 'öüäÖÜÄß<>@€µ®“«';
					my $utf8_password = Encode::decode('UTF-8', $encoded_password, 1);
					ok($login->password() eq $utf8_password, "$display_username contains a correctly encoded UTF-8 password");
					ok($login->creation_time() == 1644485034, "$display_username has a creation time of " . gmtime($login->creation_time()));
					ok($login->password_changed_time() == 1644398823, "$display_username has a password changed time of " . gmtime($login->password_changed_time()));
				}
			} else {
				ok($login->host() =~ /^https?:\/\/(?:[a-z]+[.])?[a-z]+[.](?:com|net|org)$/smx, "Firefox::Marionette::Login->host() from Firefox::Marionette->logins_from_csv('$path') looks correct:" . Encode::encode('UTF-8', $login->host(), 1));
				ok($login->user(), "Firefox::Marionette::Login->user() from Firefox::Marionette->logins_from_csv('$path') looks correct:" . Encode::encode('UTF-8', $login->user(), 1));
			}
			ok($firefox->add_login($login), "\$firefox->add_login() copes with a login from Firefox::Marionette->logins_from_csv('$path') passed directly to it");
			push @logins, $login;
		}
		if ($path eq 't/data/keepassxs.csv') {
			ok($found_utf8_user, "$path contains a UTF-8 username of $display_username for $path");
		}
		ok(scalar @logins, "$path produces Firefox::Marionette::Login records:" . scalar @logins);
		my %existing;
		foreach my $login ($firefox->logins()) {
			$existing{$login->host()}{$login->user()} = $login;
		}
		$handle = FileHandle->new($path, Fcntl::O_RDONLY()) or die "Failed to open $path:$!";
		foreach my $login (Firefox::Marionette->logins_from_csv($handle)) {
			ok(exists $existing{$login->host()}{$login->user()} && $existing{$login->host()}{$login->user()}->password() eq $login->password(), "\$firefox->logins() produces a matching login after adding record from Firefox::Marionette->logins_from_csv('$path')");
			ok($firefox->delete_login($login), "\$firefox->delete_login() copes with a login from Firefox::Marionette->logins_from_csv('$path') passed directly to it");
		}
	}
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	foreach my $path (qw(t/data/1Passwordv8.1pux)) {
		my $handle = FileHandle->new($path, Fcntl::O_RDONLY()) or die "Failed to open $path:$!";
		my @logins;
		my $encoded_username = 'tésting@au.example.org';
		my $display_username = $encoded_username;
		my $utf8_username = Encode::decode('UTF-8', $encoded_username, 1);
		my $found_utf8_user;
		foreach my $login (Firefox::Marionette->logins_from_zip($handle)) {
			ok($login->host() =~ /^https?:\/\/(?:[a-z]+[.])?[a-z]+[.](?:com|net|org)$/smx, "Firefox::Marionette::Login->host() from Firefox::Marionette->logins_from_zip('$path') looks correct:" . Encode::encode('UTF-8', $login->host(), 1));
			ok($login->user(), "Firefox::Marionette::Login->user() from Firefox::Marionette->logins_from_zip('$path') looks correct:" . Encode::encode('UTF-8', $login->user(), 1));
			if ($login->user() eq $utf8_username) {
				$found_utf8_user = 1;
				my $encoded_password = 'TGe3xQxzZ8t4nfzQ-vpY6@D4GnCQaFTuD3hDe72D3btt!';
				my $utf8_password = Encode::decode('UTF-8', $encoded_password, 1);
				ok($login->password() eq $utf8_password, "$display_username contains a correctly encoded UTF-8 password");
				ok($login->creation_time() == 1641413610, "$display_username has a creation time of " . gmtime($login->creation_time()));
				ok($login->password_changed_time() == 1641850061, "$display_username has a password changed time of " . gmtime($login->password_changed_time()));
			}
			ok($firefox->add_login($login), "\$firefox->add_login() copes with a login from Firefox::Marionette->logins_from_zip('$path') passed directly to it");
			push @logins, $login;
		}
		ok($found_utf8_user, "$path contains a UTF-8 username of $display_username for $path");
		ok(scalar @logins, "$path produces Firefox::Marionette::Login records:" . scalar @logins);
		my %existing;
		foreach my $login ($firefox->logins()) {
			$existing{$login->host()}{$login->user()} = $login;
		}
		$handle = FileHandle->new($path, Fcntl::O_RDONLY()) or die "Failed to open $path:$!";
		foreach my $login (Firefox::Marionette->logins_from_zip($handle)) {
			ok(exists $existing{$login->host()}{$login->user()} && $existing{$login->host()}{$login->user()}->password() eq $login->password(), "\$firefox->logins() produces a matching login after adding record from Firefox::Marionette->logins_from_zip('$path')");
			ok($firefox->delete_login($login), "\$firefox->delete_login() copes with a login from Firefox::Marionette->logins_from_zip('$path') passed directly to it");
		}
	}
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	foreach my $path (qw(t/data/keepass1.xml)) {
		my $handle = FileHandle->new($path, Fcntl::O_RDONLY()) or die "Failed to open $path:$!";
		my @logins;
		my $encoded_username = '!"§$%&/()=?`´²³{[]}\\';
		my $display_username = $encoded_username;
		my $utf8_username = Encode::decode('UTF-8', $encoded_username, 1);
		my $found_utf8_user;
		foreach my $login (Firefox::Marionette->logins_from_xml($handle)) {
			ok($login->host() =~ /^https?:\/\/(?:[a-z]+[.])?[a-z]+[.](?:com|net|org)(?:[:]\d+)?\/?$/smx, "Firefox::Marionette::Login->host() from Firefox::Marionette->logins_from_zip('$path') looks correct:" . Encode::encode('UTF-8', $login->host(), 1));
			ok($login->user(), "Firefox::Marionette::Login->user() from Firefox::Marionette->logins_from_zip('$path') looks correct:" . Encode::encode('UTF-8', $login->user(), 1));
			if ($login->user() eq $utf8_username) {
				$found_utf8_user = 1;
				my $encoded_password = 'öüäÖÜÄß<>@€µ®“«';
				my $utf8_password = Encode::decode('UTF-8', $encoded_password, 1);
				ok($login->password() eq $utf8_password, "$display_username contains a correctly encoded UTF-8 password");
				ok($login->creation_time() == 1167566157, "$display_username has a creation time of " . gmtime($login->creation_time()));
				ok($login->password_changed_time() == 1167566166, "$display_username has a password changed time of " . gmtime($login->password_changed_time()));
			}
			ok($firefox->add_login($login), "\$firefox->add_login() copes with a login from Firefox::Marionette->logins_from_zip('$path') passed directly to it");
			push @logins, $login;
		}
		ok($found_utf8_user, "$path contains a UTF-8 username of $display_username for $path");
		ok(scalar @logins, "$path produces Firefox::Marionette::Login records:" . scalar @logins);
		my %existing;
		foreach my $login ($firefox->logins()) {
			$existing{$login->host()}{$login->user()} = $login;
		}
		$handle = FileHandle->new($path, Fcntl::O_RDONLY()) or die "Failed to open $path:$!";
		foreach my $login (Firefox::Marionette->logins_from_xml($handle)) {
			ok(exists $existing{$login->host()}{$login->user()} && $existing{$login->host()}{$login->user()}->password() eq $login->password(), "\$firefox->logins() produces a matching login after adding record from Firefox::Marionette->logins_from_zip('$path')");
			ok($firefox->delete_login($login), "\$firefox->delete_login() copes with a login from Firefox::Marionette->logins_from_zip('$path') passed directly to it");
		}
	}
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() shows the correct number (0) of records");
	my $test_login = Firefox::Marionette::Login->new(host => 'https://github.com', user => 'ddick@cpan.org', password => 'qwerty', user_field => 'login', password_field => 'password', creation_in_ms => 0, last_used_in_ms => undef);
	ok(!defined $test_login->last_used_time(), "Firefox::Marionette::Login->new()->last_used_time() correctly returns undef for an undefined parameter to new");
	ok($test_login->creation_time() == 0, "Firefox::Marionette::Login->new()->creation_time() correctly returns 0 for a 0 parameter to new");
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	diag("Starting new firefox for testing custom headers");
	my %extra_parameters;
	my $visible = 0;
	if ($nightly || $developer) {
		$visible = 1;
		$extra_parameters{visible} = $visible;
		diag("Forcing visible for nightly firefox to dodge issues with geo/har methods");
	}
	($skip_message, $firefox) = start_firefox($visible, har => 1, debug => 0, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 1), geo => URI->new($freeipapi_uri), %extra_parameters);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 6);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to known values");
	if ($major_version >= 60) {
		my $title = "This is MetaCPAN!";
		my $bookmark = Firefox::Marionette::Bookmark->new( url => $metacpan_uri, title => $title);
		ok($firefox->add_bookmark($bookmark), "Added a new bookmark to firefox");
		TODO: {
			local $TODO = $major_version <= 80 && $major_version >= 70 ? "Temporary problems with bookmarks" : q[];
			my $guid;
			my $count = 0;
			foreach my $result ($firefox->bookmarks($metacpan_uri)) {
				ok($result->url() eq $metacpan_uri, "Retrieved the correct bookmark");
				$guid = $result->guid();
				ok($guid, "Found $guid as the guid of the new bookmark");
				$count += 1;
			}
			ok($count == 1, "Total number of bookmarks found when searching by url is 1:$count");
			$count = 0;
			foreach my $result ($firefox->bookmarks(url => $metacpan_uri)) {
				ok($result->url() eq $metacpan_uri, "Retrieved the correct bookmark");
				$count += 1;
			}
			ok($count == 1, "Total number of bookmarks found when searching by (url => '$metacpan_uri') is 1:$count");
			$count = 0;
			foreach my $result ($firefox->bookmarks(url => URI->new($metacpan_uri))) {
				ok($result->url() eq $metacpan_uri, "Retrieved the correct bookmark");
				$count += 1;
			}
			ok($count == 1, "Total number of bookmarks found when searching by (url => URI->new('$metacpan_uri')) is 1:$count");
			$count = 0;
			foreach my $result ($firefox->bookmarks($title)) {
				ok($result->url() eq $metacpan_uri, "Retrieved the correct bookmark");
				$count += 1;
			}
			ok($count == 1, "Total number of bookmarks found when searching by title is 1:$count");
			$count = 0;
			foreach my $result ($firefox->bookmarks(title => $title)) {
				ok($result->url() eq $metacpan_uri, "Retrieved the correct bookmark");
				$count += 1;
			}
			ok($count == 1, "Total number of bookmarks found when searching by (title => '$title') is 1:$count");
		}
	}
	ok(scalar $firefox->logins() == 0, "\$firefox->logins() has no entries:" . scalar $firefox->logins());
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
	if (($ENV{RELEASE_TESTING}) && (!$ENV{FIREFOX_NO_NETWORK})) { # har sometimes hangs and sometimes metacpan.org fails certificate checks.  for example. http://www.cpantesters.org/cpan/report/e71bfb3b-7413-1014-98e6-045206f7812f
		if (!$tls_tests_ok) {
			skip("TLS test infrastructure seems compromised", 5);
		}
		if ($^O eq 'darwin') {
			if (($firefox->nightly()) || ($firefox->developer())) {
				skip("github actions are having trouble for Darwin nightly", 5);
				diag("github actions are having trouble for Darwin nightly");
			}
		}
		ok($firefox->go(URI->new("https://fastapi.metacpan.org/author/DDICK")), "https://fastapi.metacpan.org/author/DDICK has been loaded");
		ok($firefox->interactive() && $firefox->loaded(), "\$firefox->interactive() and \$firefox->loaded() are ok");
		if ($major_version < 61) {
			skip("HAR support not available in Firefox before version 61", 1);
		}
		if ($major_version >= $min_geo_version) {
			my $geo6;
			eval {
				$geo6 = $firefox->geo();
			} or do {
				chomp $@;
				diag("Threw an exception in geo method:$@");
			};
			if ((!defined $geo6) && (($uname eq 'cygwin') || ($uname eq 'MSWin32'))) {
				diag("Location services may be disabled");
				eval {
					$firefox->dismiss_alert();
				};
			} elsif (defined $geo6) {
				ok($geo6->latitude() == -37.5, "\$firefox->geo()->latitude() returned -31.5:" . $geo6->latitude());
				ok($geo6->longitude() == 144.5, "\$firefox->geo()->longitude() returned 144.5:" . $geo6->longitude());
			}
		}
		my $correct = 0;
		my $number_of_entries = 0;
		my $count = 0;
		GET_HAR: while($number_of_entries == 0) {
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
			sleep 1;
			$count += 1;
			if ($count > 20) {
				diag("Unable to find any HAR entries for 20 seconds");
				last GET_HAR;
			}
		}
		if (($uname eq 'cygwin') || ($uname eq 'MSWin32') || ($uname eq 'FreeBSD')) {
			TODO: {
				local $TODO = "$uname can fail this test";
				ok($correct == 4, "Correct headers have been set");
			}
		} else {
			ok($correct == 4, "Correct headers have been set");
		}
	}
}

my $bad_network_behaviour;
SKIP: {
	diag("Starting new firefox for testing metacpan and iframe, with find, downloads, extensions and actions");
	$profile->set_value('general.useragent.override', 'libwww-perl/6.72');
	($skip_message, $firefox) = start_firefox(0, debug => 0, page_load => 600000, script => 5432, profile => $profile, capabilities => Firefox::Marionette::Capabilities->new(accept_insecure_certs => 1, page_load_strategy => 'eager'), geo => $freeipapi_uri);
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 247);
	}
	ok($firefox, "Firefox has started in Marionette mode without defined capabilities, but with a defined profile and debug turned off");
	my $agent;
	eval {
		$agent = $firefox->agent( os => 'Linux' );
	};
	ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->agent(os => 'Linux') fails when general.useragent.override is already set to an unparsable value:$@");

	my $chrome_window_handle_supported;
	eval {
		$chrome_window_handle_supported = $firefox->chrome_window_handle();
	} or do {
		diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version:$@");
	};
	if ($ENV{FIREFOX_HOST}) {
	} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
	} else {
		# Coping with OpenBSD unveil - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271
		my $path = File::Spec->catfile(Cwd::cwd(), qw(t data elements.html));
		if ($^O eq 'cygwin') {
			$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
		}
		my $frame_url = "file://$path";
		my $frame_element = '//iframe[@name="iframe"]';
		ok($firefox->go($frame_url), "$frame_url has been loaded");
		if (out_of_time()) {
			skip("Running out of time.  Trying to shutdown tests as fast as possible", 246);
		}
		if ($major_version >= $min_geo_version) {
			if (my $geo = $firefox->geo()) {
				ok($geo->latitude() == -37.5, "\$firefox->geo()->latitude() returned -31.5:" . $geo->latitude());
				ok($geo->longitude() == 144.5, "\$firefox->geo()->longitude() returned 144.5:" . $geo->longitude());
			} elsif (($uname eq 'cygwin') || ($uname eq 'MSWin32')) {
				diag("Location services may be disabled");
				eval {
					$firefox->dismiss_alert();
				};
			}
		}
		if ($major_version >= 121) {
			my @frames = sort @{$firefox->script("return [ window.frames[0], window.frames[1] ];")};
			ok($frames[0]->isa('Firefox::Marionette::WebFrame') && $frames[1]->isa('Firefox::Marionette::WebFrame') && (scalar @frames == 2), "An array from javascript of frames returns WebFrame objects");
		}
		my $first_window_handle = $firefox->window_handle();
		if ($major_version < 90) {
			ok($first_window_handle =~ /^\d+$/, "\$firefox->window_handle() is an integer:" . $first_window_handle);
		} else {
			ok($first_window_handle =~ /^$guid_regex$/smx, "\$firefox->window_handle() is a GUID:" . $first_window_handle);
		}
		SKIP: {
			if (!$chrome_window_handle_supported) {
				diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
				skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
			}
			if ($major_version < 90) {
				ok($chrome_window_handle_supported =~ /^\d+$/, "\$firefox->chrome_window_handle() is an integer:" . $chrome_window_handle_supported);
			} else {
				ok($chrome_window_handle_supported =~ /^$guid_regex$/smx, "\$firefox->chrome_window_handle() is a GUID:" . $chrome_window_handle_supported);
			}
		}
		ok($firefox->capabilities()->timeouts()->script() == 5432, "\$firefox->capabilities()->timeouts()->script() correctly reflects the scripts shortcut timeout:" . $firefox->capabilities()->timeouts()->script());
		SKIP: {
			if (!$chrome_window_handle_supported) {
				diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
				skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 2);
			}
			if ($major_version < 90) {
				ok($firefox->chrome_window_handle() == $firefox->current_chrome_window_handle(), "\$firefox->chrome_window_handle() is equal to \$firefox->current_chrome_window_handle()");
			} else {
				ok($firefox->chrome_window_handle() eq $firefox->current_chrome_window_handle(), "\$firefox->chrome_window_handle() is equal to \$firefox->current_chrome_window_handle()");
			}
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
				if ($major_version < 90) {
					ok($handle =~ /^\d+$/, "\$firefox->chrome_window_handles() returns a list of integers:" . $handle);
				} else {
					ok($handle =~ /^$guid_regex$/, "\$firefox->chrome_window_handles() returns a list of GUIDs:" . $handle);
				}
			}
		}
		my ($original_window_handle) = $firefox->window_handles();
		foreach my $handle ($firefox->window_handles()) {
			if ($major_version < 90) {
				ok($handle =~ /^\d+$/, "\$firefox->window_handles() returns a list of integers:" . $handle);
			} else {
				ok($handle =~ /^$guid_regex$/, "\$firefox->window_handles() returns a list of GUIDs:" . $handle);
			}
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
				if ($major_version < 90) {
					ok($handle =~ /^\d+$/, "\$firefox->chrome_window_handles() returns a list of integers:" . $handle);
				} else {
					ok($handle =~ /^$guid_regex$/, "\$firefox->chrome_window_handles() returns a list of GUIDs:" . $handle);
				}
				if ($handle ne $original_chrome_window_handle) {
					$new_chrome_window_handle = $handle;
				}
			}
			ok($new_chrome_window_handle, "New chrome window handle $new_chrome_window_handle detected");
		}
		my $new_window_handle;
		foreach my $handle ($firefox->window_handles()) {
			if ($major_version < 90) {
				ok($handle =~ /^\d+$/, "\$firefox->window_handles() returns a list of integers:" . $handle);
			} else {
				ok($handle =~ /^$guid_regex$/, "\$firefox->window_handles() returns a list of GUIDs:" . $handle);
			}
			if ($handle ne $original_window_handle) {
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
				if (($@->isa('Firefox::Marionette::Exception')) && ($@ =~ /(?:Only supported in Fennec|unsupported operation: Only supported on Android)/)) {
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
			if ($major_version >= 121) {
				my $script_window = $firefox->script("return window");
				my $initial_url = $firefox->script("return window.location.href");
				ok($script_window->isa('Firefox::Marionette::WebFrame'), "\$firefox->script(\"return window\") returns a Firefox::Marionette::Frame object");
				my $argument_url = $firefox->script("return arguments[0].location.href", args => [ $script_window ]);
				ok($argument_url eq $initial_url, "window object can be used as an in and out parameter for javascript calls:$argument_url:$initial_url");
			}
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
		my $browser_name = $firefox->capabilities()->browser_name();
		SKIP: {
			if (!$chrome_window_handle_supported) {
				diag("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
				skip("\$firefox->chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
			}
			foreach my $handle ($firefox->close_current_chrome_window_handle()) {
				local $TODO = $major_version < 52 || $browser_name =~ /waterfox/i ? "\$firefox->close_current_chrome_window_handle() can return a undef value for versions less than 52 or browser is waterfox" : undef;
				if ($major_version < 90) {
					ok(defined $handle && $handle == $new_chrome_window_handle, "Closed original window, which means the remaining chrome window handle should be $new_chrome_window_handle:" . ($handle || ''));
				} else {
					ok(defined $handle && $handle eq $new_chrome_window_handle, "Closed original window, which means the remaining chrome window handle should be $new_chrome_window_handle:" . ($handle || ''));
				}
			}
		}
		ok($firefox->switch_to_window($new_window_handle), "\$firefox->switch_to_window() used to move back to the original window");
	}
	if (!($ENV{RELEASE_TESTING}) || ($ENV{FIREFOX_NO_NETWORK})) {
		skip("Skipping network tests", 225);
	}
	ok($firefox->refresh(), "\$firefox->refresh()");
	ok($firefox->go($metacpan_uri), "$metacpan_uri has been loaded in the new window");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 224);
	}
	my $uri = $firefox->uri();
	if ($uri eq $metacpan_uri) {
		ok($uri =~ /metacpan/smx, "\$firefox->uri() contains /metacpan/:$uri");
	} else {
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
		$bad_network_behaviour = 1;
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
	ok($firefox->page_source() =~ /Search[ ]the[ ]CPAN/smx, "metacpan.org contains the phrase 'Search the CPAN' in page source");
	ok($firefox->html() =~ /Search[ ]the[ ]CPAN/smx, "metacpan.org contains the phrase 'Search the CPAN' in html");
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
	my @links = $firefox->links();
	ok(scalar @links, "Found " . (scalar @links) . " links in metacpan.org");
	my $number_of_links = 0;
	foreach my $link (@links) {
		if (defined $link->url()) {
			ok($link->url(), "Link from metacpan.org has a url of " . $link->url());
		}
		if (my $text = $link->text()) {
			ok($link->text(), "Link from metacpan.org has text of " . $text);
		}
		if ($link->name()) {
			ok($link->name(), "Link from metacpan.org has name of " . $link->name());
		}
		if (defined $link->tag()) {
			ok($link->tag(), "Link from metacpan.org has a tag of " . $link->tag());
		}
		if (defined $link->base()) {
			ok($link->base(), "Link from metacpan.org has a base of " . $link->base());
		}
		if ($link->URI()) {
			ok($link->URI() && $link->URI()->isa('URI::URL'), "Link from metacpan.org has a URI of " . $link->URI());
		}
		if ($link->url_abs()) {
			ok($link->url_abs(), "Link from metacpan.org has a url_abs of " . $link->url_abs());
		}
		my %attributes = $link->attrs();
		my $count = 0;
		foreach my $key (sort { $a cmp $b } keys %attributes) {
			ok($key, "Link from metacpan.org has a attribute called '" . $key . "' with a value of '" . $attributes{$key} . "'");
			$count += 1;
		}
		ok($count, "Link from metacpan.org has $count attributes");
		my @scroll_arguments = test_scroll_arguments($number_of_links++);
		ok($link->scroll(@scroll_arguments), "Firefox scrolled to the link with arguments of:" . join q[, ], stringify_scroll_arguments(@scroll_arguments));
	}
	my @images = $firefox->images();
	foreach my $image (@images) {
		ok($image->url(), "Image from metacpan.org has a url of " . $image->url());
		ok($image->height(), "Image from metacpan.org has height of " . $image->height());
		ok($image->width(), "Image from metacpan.org has width of " . $image->width());
		if ($image->alt()) {
			ok($image->alt(), "Image from metacpan.org has alt of " . $image->alt());
		}
		if ($image->name()) {
			ok($image->name(), "Image from metacpan.org has name of " . $image->name());
		}
		if (defined $image->tag()) {
			ok($image->tag() =~ /^(image|input)$/smx, "Image from metacpan.org has a tag of " . $image->tag());
		}
		if (defined $image->base()) {
			ok($image->base(), "Image from metacpan.org has a base of " . $image->base());
		}
		if ($image->URI()) {
			ok($image->URI() && $image->URI()->isa('URI::URL'), "Image from metacpan.org has a URI of " . $image->URI());
		}
		if ($image->url_abs()) {
			ok($image->url_abs(), "Image from metacpan.org has a url_abs of " . $image->url_abs());
		}
		my %attributes = $image->attrs();
		my $count = 0;
		foreach my $key (sort { $a cmp $b } keys %attributes) {
			ok($key, "Image from metacpan.org has a attribute called '" . $key . "' with a value of '" . $attributes{$key} . "'");
			$count += 1;
		}
		ok($count, "Image from metacpan.org has $count attributes");
	}
	my $search_box_id;
	foreach my $element ($firefox->has_tag('input')) {
		if ((lc $element->attribute('type')) eq 'text') {
			$search_box_id = $element->attribute('id');
		}
	}
	ok($firefox->find('//input[@id="' . $search_box_id . '"]', BY_XPATH())->type('Firefox::Marionette'), "Sent 'Firefox::Marionette' to the '$search_box_id' field directly to the element");
	my $autofocus;
	ok($autofocus = $firefox->find_element('//input[@id="' . $search_box_id . '"]')->attribute('autofocus'), "The value of the autofocus attribute is '$autofocus'");
	$autofocus = undef;
	eval {
		$autofocus = $firefox->find('//input[@id="' . $search_box_id . '"]')->property('autofocus');
	};
	SKIP: {
		if ((!$autofocus) && ($major_version < 50)) {
			chomp $@;
			diag("The property method is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("The property method is not supported for $major_version.$minor_version.$patch_version", 4);
		}
		ok($autofocus, "The value of the autofocus property is '$autofocus'");
		ok($firefox->find_by_class($page_content)->find('//input[@id="' . $search_box_id . '"]')->property('id') eq $search_box_id, "Correctly found nested element with find");
		ok($firefox->title() eq $firefox->find_tag('title')->property('innerHTML'), "\$firefox->title() is the same as \$firefox->find_tag('title')->property('innerHTML')");
	}
	my $count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->list('//input[@id="' . $search_box_id . '"]')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with list");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->find('//input[@id="' . $search_box_id . '"]')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with find");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find:$count");
	$count = 0;
	foreach my $element ($firefox->has_class($page_content)->has('//input[@id="' . $search_box_id . '"]')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with has");
		$count += 1;
	}
	$count = 0;
	foreach my $element ($firefox->has_class($page_content)->has('//input[@id="not-an-element-at-all-or-ever"]')) {
		$count += 1;
	}
	ok($count == 0, "Found no elements with nested has:$count");
	$count = 0;
	foreach my $element ($firefox->find('//input[@id="' . $search_box_id . '"]')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found element with wantarray find");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find:$count");
	ok($firefox->find($search_box_id, 'id')->attribute('id') eq $search_box_id, "Correctly found element when searching by id");
	ok($firefox->find($search_box_id, BY_ID())->attribute('id') eq $search_box_id, "Correctly found element when searching by id");
	ok($firefox->has($search_box_id, BY_ID())->attribute('id') eq $search_box_id, "Correctly found element for default has");
	ok($firefox->list_by_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found element with list_by_id");
	ok($firefox->find_by_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found element with find_by_id");
	ok($firefox->find_by_class($page_content)->find_by_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found nested element with find_by_id");
	ok($firefox->find_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found element with find_id");
	ok($firefox->has_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found element with has_id");
	ok(!defined $firefox->has_id('search-input-totally-not-there-EVER'), "Correctly returned undef with has_id for a non existant element");
	ok($firefox->find_class($page_content)->find_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found nested element with find_id");
	ok($firefox->has_class($page_content)->has_id($search_box_id)->attribute('id') eq $search_box_id, "Correctly found nested element with has_id");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->list_by_id($search_box_id)) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with list_by_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list_by_id:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->find_by_id($search_box_id)) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with find_by_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_id:$count");
	$count = 0;
	foreach my $element ($firefox->find_class($page_content)->find_id($search_box_id)) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with find_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_id:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_id($search_box_id)) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found element with wantarray find_by_id");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_id:$count");
	ok($firefox->find('q', 'name')->attribute('id') eq $search_box_id, "Correctly found element when searching by id");
	ok($firefox->find('q', BY_NAME())->attribute('id') eq $search_box_id, "Correctly found element when searching by id");
	ok($firefox->list_by_name('q')->attribute('id') eq $search_box_id, "Correctly found element with list_by_name");
	ok($firefox->find_by_name('q')->attribute('id') eq $search_box_id, "Correctly found element with find_by_name");
	ok($firefox->find_by_class($page_content)->find_by_name('q')->attribute('id') eq $search_box_id, "Correctly found nested element with find_by_name");
	ok($firefox->find_name('q')->attribute('id') eq $search_box_id, "Correctly found element with find_name");
	ok($firefox->has_name('q')->attribute('id') eq $search_box_id, "Correctly found element with has_name");
	ok(!defined $firefox->has_name('q-definitely-not-exists'), "Correctly returned undef for has_name and a missing element");
	ok($firefox->find_class($page_content)->find_name('q')->attribute('id') eq $search_box_id, "Correctly found nested element with find_name");
	ok($firefox->has_class($page_content)->has_name('q')->attribute('id') eq $search_box_id, "Correctly found nested element with has_name");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->list_by_name('q')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with list_by_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list_by_name:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->find_by_name('q')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found nested element with find_by_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_name:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_name('q')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found element with wantarray find_by_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_name:$count");
	$count = 0;
	foreach my $element ($firefox->find_name('q')) {
		ok($element->attribute('id') eq $search_box_id, "Correctly found element with wantarray find_name");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_name:$count");
	ok($firefox->find('input', 'tag name')->attribute('id'), "Correctly found element when searching by tag name");
	ok($firefox->find('input', BY_TAG())->attribute('id'), "Correctly found element when searching by tag name");
	ok($firefox->list_by_tag('input')->attribute('id'), "Correctly found element with list_by_tag");
	ok($firefox->find_by_tag('input')->attribute('id'), "Correctly found element with find_by_tag");
	ok($firefox->find_by_class($page_content)->find_by_tag('input')->attribute('id'), "Correctly found nested element with find_by_tag");
	ok($firefox->find_tag('input')->attribute('id'), "Correctly found element with find_tag");
	ok($firefox->has_tag('input')->attribute('id'), "Correctly found element with has_tag");
	ok($firefox->find_class($page_content)->find_tag('input')->attribute('id'), "Correctly found nested element with find_tag");
	ok($firefox->has_class($page_content)->has_tag('input')->attribute('id'), "Correctly found nested element with has_tag");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->list_by_tag('input')) {
		ok($element->attribute('id'), "Correctly found nested element with list_by_tag");
		$count += 1;
	}
	ok($count == 2, "Found elements with nested list_by_tag:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->find_by_tag('input')) {
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
	ok($firefox->find($form_control, 'class name')->attribute('id'), "Correctly found element when searching by class name");
	ok($firefox->find($form_control, BY_CLASS())->attribute('id'), "Correctly found element when searching by class name");
	ok($firefox->list_by_class($form_control)->attribute('id'), "Correctly found element with list_by_class");
	ok($firefox->find_by_class($form_control)->attribute('id'), "Correctly found element with find_by_class");
	ok($firefox->find_by_class($page_content)->find_by_class($form_control)->attribute('id'), "Correctly found nested element with find_by_class");
	ok($firefox->find_class($form_control)->attribute('id'), "Correctly found element with find_class");
	ok($firefox->find_class($page_content)->find_class($form_control)->attribute('id'), "Correctly found nested element with find_class");
	ok($firefox->has_class($page_content)->has_class($form_control)->attribute('id'), "Correctly found nested element with has_class");
	ok(!defined $firefox->has_class($page_content)->has_class('absolutely-can-never-exist-in-any-universe-seriously-10'), "Correctly returned undef for nested element with has_class for a missing class");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->list_by_class($form_control)) {
		ok($element->attribute('id'), "Correctly found nested element with list_by_class");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_class:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->find_by_class($form_control)) {
		ok($element->attribute('id'), "Correctly found element with wantarray find_by_class");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_class:$count");
	$count = 0;
	foreach my $element ($firefox->find_class($page_content)->find_class($form_control)) {
		ok($element->attribute('id'), "Correctly found element with wantarray find_class");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_class:$count");
	ok($firefox->find($css_form_control, 'css selector')->attribute('id'), "Correctly found element when searching by css selector");
	ok($firefox->find($css_form_control, BY_SELECTOR())->attribute('id'), "Correctly found element when searching by css selector");
	ok($firefox->list_by_selector($css_form_control)->attribute('id'), "Correctly found element with list_by_selector");
	ok($firefox->find_by_selector($css_form_control)->attribute('id'), "Correctly found element with find_by_selector");
	ok($firefox->find_by_class($page_content)->find_by_selector($css_form_control)->attribute('id'), "Correctly found nested element with find_by_selector");
	ok($firefox->find_selector($css_form_control)->attribute('id'), "Correctly found element with find_selector");
	ok($firefox->find_class($page_content)->find_selector($css_form_control)->attribute('id'), "Correctly found nested element with find_selector");
	ok($firefox->has_class($page_content)->has_selector($css_form_control)->attribute('id'), "Correctly found nested element with has_selector");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->list_by_selector($css_form_control)) {
		ok($element->attribute('id'), "Correctly found nested element with list_by_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested list_by_selector:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_class($page_content)->find_by_selector($css_form_control)) {
		ok($element->attribute('id'), "Correctly found nested element with find_by_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with nested find_by_selector:$count");
	$count = 0;
	foreach my $element ($firefox->has_selector($css_form_control)) {
		ok($element->attribute('id'), "Correctly found wantarray element with has_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray has_selector:$count");
	$count = 0;
	foreach my $element ($firefox->find_by_selector($css_form_control)) {
		ok($element->attribute('id'), "Correctly found wantarray element with find_by_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_selector:$count");
	$count = 0;
	foreach my $element ($firefox->find_selector($css_form_control)) {
		ok($element->attribute('id'), "Correctly found wantarray element with find_selector");
		$count += 1;
	}
	ok($count == 1, "Found elements with wantarray find_by_selector:$count");
	my $metacpan_api_hostname = q[api.metacpan.org];
	my $metacpan_api_url_regex = qr/https:\/\// . (quotemeta $metacpan_api_hostname) . qr/\/?/smx;
	ok($firefox->find('API', 'link text')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element when searching by link text");
	ok($firefox->find('API', BY_LINK())->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element when searching by link text");
	ok($firefox->list_by_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with list_by_link");
	ok($firefox->find_by_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with find_by_link");
	TODO: {
		local $TODO = $major_version == 45 ? "Nested find_link can break for $major_version.$minor_version.$patch_version" : undef;
		my $result;
		eval {
			$result = $firefox->find_by_class($footer_links)->find_by_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx;
		};
		ok($result, "Correctly found nested element with find_by_link");
	}
	ok($firefox->find_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with find_link");
	ok($firefox->has_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with has_link");
	TODO: {
		local $TODO = $major_version == 45 ? "Nested find_link can break for $major_version.$minor_version.$patch_version" : undef;
		my $result;
		eval {
			$result = $firefox->find_class($footer_links)->find_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx;
		};
		ok($result, "Correctly found nested element with find_link");
		eval {
			$result = $firefox->has_class($footer_links)->has_link('API')->attribute('href') =~ /^$metacpan_api_url_regex$/smx;
		};
		ok($result, "Correctly found nested element with has_link");
	}
	$count = 0;
	foreach my $element ($firefox->find_by_class($footer_links)->list_by_link('API')) {
		ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with list_by_link");
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
	foreach my $element ($firefox->find_by_class($footer_links)->find_by_link('API')) {
		ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with find_by_link");
		$count += 1;
	}
	SKIP: {
		if (($count == 0) && ($major_version < 50)) {
			chomp $@;
			diag("Nested find_by_link can break for $major_version.$minor_version.$patch_version:$@");
			skip("Nested find_by_link can break for $major_version.$minor_version.$patch_version", 2);
		}
		if ($major_version >= 61) {
			ok($count == 1, "Found elements with nested find_by_link:$count");
		} else {
			ok((($count == 1) or ($count == 2)), "Found elements with nested find_by_link:$count");
		}
	}
	$count = 0;
	foreach my $element ($firefox->find_by_link('API')) {
		ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found wantarray element with find_by_link");
		$count += 1;
	}
	if (($count == 1) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for find_by_link", 2);
		}
	} else {
		if ($major_version >= 61) {
			ok($count == 1, "Found elements with wantarray find_by_link:$count");
		} else {
			ok((($count == 1) or ($count == 2)), "Found elements with wantarray find_by_link:$count");
		}
	}
	$count = 0;
	foreach my $element ($firefox->find_link('API')) {
		ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found wantarray element with find_link");
		$count += 1;
	}
	if (($count == 1) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for find_link", 2);
		}
	} else {
		if ($major_version >= 61) {
			ok($count == 1, "Found elements with wantarray find_link:$count");
		} else {
			ok((($count == 1) or ($count == 2)), "Found elements with wantarray find_link:$count");
		}
	}
	ok($firefox->find('AP', 'partial link text')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element when searching by partial link text");
	ok($firefox->find('AP', BY_PARTIAL())->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element when searching by partial link text");
	ok($firefox->list_by_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with list_by_partial");
	ok($firefox->find_by_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with find_by_partial");
	ok($firefox->find_by_class($footer_links)->find_by_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with find_by_partial");
	ok($firefox->find_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with find_partial");
	ok($firefox->has_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found element with has_partial");
	ok($firefox->find_class($footer_links)->find_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with find_partial");
	ok($firefox->has_class($footer_links)->has_partial('AP')->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with has_partial");
	$count = 0;
	foreach my $element ($firefox->find_by_class($footer_links)->list_by_partial('AP')) {
		if ($count == 0) {
			ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with list_by_partial");
		}
		$count +=1;
	}
	if (($count == 2) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for list_by_partial", 1);
		}
	} else {
		if ($major_version >= 61) {
			ok($count == 1, "Found elements with nested list_by_partial:$count");
		} else {
			ok((($count == 1) or ($count == 2)), "Found elements with nested list_by_partial:$count");
		}
	}
	$count = 0;
	foreach my $element ($firefox->find_by_class($footer_links)->find_by_partial('AP')) {
		if ($count == 0) {
			ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found nested element with find_by_partial");
		}
		$count +=1;
	}
	if (($count == 2) && ($major_version < 50)) {
		SKIP: {
			skip("Firefox $major_version.$minor_version.$patch_version does not correctly implement returning multiple elements for find_by_partial", 1);
		}
	} else {
		if ($major_version >= 61) {
			ok($count == 1, "Found elements with nested find_by_partial:$count");
		} else {
			ok((($count == 1) or ($count == 2)), "Found elements with nested find_by_partial:$count");
		}
	}
	$count = 0;
	foreach my $element ($firefox->find_by_partial('AP')) {
		ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found wantarray element with find_by_partial");
		$count +=1;
	}
	if ($major_version >= 61) {
		ok($count == 1, "Found elements with wantarray find_by_partial:$count");
	} else {
		ok((($count == 1) or ($count == 2)), "Found elements with wantarray find_by_partial:$count");
	}
	$count = 0;
	foreach my $element ($firefox->find_partial('AP')) {
		ok($element->attribute('href') =~ /^$metacpan_api_url_regex$/smx, "Correctly found wantarray element with find_partial");
		$count +=1;
	}
	if ($major_version >= 61) {
		ok($count == 1, "Found elements with wantarray find_partial:$count");
	} else {
		ok((($count == 1) or ($count == 2)), "Found elements with wantarray find_partial:$count");
	}
	my $css_rule;
	ok($css_rule = $firefox->find('//input[@id="' . $search_box_id . '"]')->css('display'), "The value of the css rule 'display' is '$css_rule'");
	my $result = $firefox->find('//input[@id="' . $search_box_id . '"]')->is_enabled();
	ok($result =~ /^[01]$/, "is_enabled returns 0 or 1 for //input[\@id=\"$search_box_id\"]:$result");
	$result = $firefox->find('//input[@id="' . $search_box_id . '"]')->is_displayed();
	ok($result =~ /^[01]$/, "is_displayed returns 0 or 1 for //input[\@id=\"$search_box_id\"]:$result");
	$result = $firefox->find('//input[@id="' . $search_box_id . '"]')->is_selected();
	ok($result =~ /^[01]$/, "is_selected returns 0 or 1 for //input[\@id=\"$search_box_id\"]:$result");
	ok($firefox->find('//input[@id="' . $search_box_id . '"]')->clear(), "Clearing the element directly");
	TODO: {
		local $TODO = $major_version < 50 ? "property and attribute methods can have different values for empty" : undef;
		ok((!defined $firefox->find_id($search_box_id)->attribute('value')) && ($firefox->find_id($search_box_id)->property('value') eq ''), "Initial property and attribute values are empty for $search_box_id");
	}
	ok($firefox->find('//input[@id="' . $search_box_id . '"]')->send_keys('Firefox::Marionette'), "Sent 'Firefox::Marionette' to the '$search_box_id' field directly to the element");
	TODO: {
		local $TODO = $major_version < 50 ? "attribute method can have different values for empty" : undef;
		ok(!defined $firefox->find_id($search_box_id)->attribute('value'), "attribute for '$search_box_id' is still not defined ");
	}
	my $property;
	eval {
		$property = $firefox->find_id($search_box_id)->property('value');
	};
	SKIP: {
		if ((!$property) && ($major_version < 50)) {
			chomp $@;
			diag("The property method is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("The property method is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		ok($property eq 'Firefox::Marionette', "property for '$search_box_id' is now 'Firefox::Marionette'");
	}
	ok($firefox->find('//input[@id="' . $search_box_id . '"]')->clear(), "Clearing the element directly");
	foreach my $element ($firefox->find_elements('//input[@id="' . $search_box_id . '"]')) {
		ok($firefox->send_keys($element, 'Firefox::Marionette'), "Sent 'Firefox::Marionette' to the '$search_box_id' field via the browser");
		ok($firefox->clear($element), "Clearing the element via the browser");
		ok($firefox->type($element, 'Firefox::Marionette'), "Sent 'Firefox::Marionette' to the '$search_box_id' field via the browser");
		last;
	}
	my $text = $firefox->find($xpath_for_read_text_and_size)->text();
	ok($text, "Read '$text' directly from '$xpath_for_read_text_and_size'");
	my $tag_name = $firefox->find($xpath_for_read_text_and_size)->tag_name();
	ok($tag_name, "'Lucky' button has a tag name of '$tag_name'");
	my $rect;
	eval {
		$rect = $firefox->find($xpath_for_read_text_and_size)->rect();
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
	$handle = $firefox->find($xpath_for_read_text_and_size)->selfie();
	ok(ref $handle eq 'File::Temp', "\$firefox->selfie() returns a File::Temp object");
	$handle->read($buffer, 20);
	ok($buffer =~ /^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A/smx, "\$firefox->find('$xpath_for_read_text_and_size')->selfie() returns a PNG file");
	if ($major_version < 31) {
		SKIP: {
			skip("Firefox before 31 can hang when processing the hash parameter", 3);
		}
	} else {
		my $actual_digest = $firefox->selfie(hash => 1, highlights => [ $firefox->find($xpath_for_read_text_and_size) ]);
		SKIP: {
			if (($major_version < 50) && ($actual_digest !~ /^[a-f0-9]+$/smx)) {
				skip("Firefox $major_version does not appear to support the hash parameter for the \$firefox->selfie method", 1);
			}
			ok($actual_digest =~ /^[a-f0-9]+$/smx, "\$firefox->selfie(hash => 1, highlights => [ \$firefox->find('$xpath_for_read_text_and_size') ]) returns a hex encoded SHA256 digest");
		}
		$handle = $firefox->selfie(highlights => [ $firefox->find($xpath_for_read_text_and_size) ]);
		$buffer = undef;
		$handle->read($buffer, 20);
		ok($buffer =~ /^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A/smx, "\$firefox->selfie(highlights => [ \$firefox->find('$xpath_for_read_text_and_size') ]) returns a PNG file");
		$handle->seek(0,0) or die "Failed to seek:$!";
		$handle->read($buffer, 1_000_000) or die "Failed to read:$!";
		my $correct_digest = Digest::SHA::sha256_hex(MIME::Base64::encode_base64($buffer, q[]));
		TODO: {
			local $TODO = "Digests can sometimes change for all platforms";
			ok($actual_digest eq $correct_digest, "\$firefox->selfie(hash => 1, highlights => [ \$firefox->find('$xpath_for_read_text_and_size') ]) returns the correct hex encoded SHA256 hash of the base64 encoded image");
		}
	}
	my $clicked;
	my $xpath = qq(//a[\@href="https://$metacpan_api_hostname/"]);
	my @elements = $firefox->find($xpath);
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 61);
	}
	ELEMENTS: {
		foreach my $element (@elements) {
			diag("Clicking on API link with " . $element->uuid());
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
	$cookie = Firefox::Marionette::Cookie->new(name => 'BonusSessionCookie', value => 'will go away anyway', sameSite => 0, httpOnly => 0, secure => 0);
	ok($firefox->add_cookie($cookie), "\$firefox->add_cookie() adds a Firefox::Marionette::Cookie without expiry");
	$cookie = Firefox::Marionette::Cookie->new(name => 'StartingCookie', value => 'not sure aböut this', httpOnly => 1, secure => 1, sameSite => 1);
	ok($firefox->add_cookie($cookie), "\$firefox->add_cookie() adds a Firefox::Marionette::Cookie with a domain");
	if (out_of_time()) {
		skip("Running out of time.  Trying to shutdown tests as fast as possible", 36);
	}
	my $dummy_object = bless {}, 'What::is::this::object';
	foreach my $name (qw(
				aria_label
				aria_role
				clear
				click
				is_displayed
				is_enabled
				is_selected
				rect
				scroll
				tag_name
				text
				type
			)) {
		eval {
			$firefox->$name({});
		};
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->$name() with a hash parameter produces a Firefox::Marionette::Exception exception");
		eval {
			$firefox->$name(q[]);
		};
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->$name() with a non ref parameter produces a Firefox::Marionette::Exception exception");
		eval {
			$firefox->$name($dummy_object);
		};
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->$name() with a non Element blessed parameter produces a Firefox::Marionette::Exception exception");
		eval {
			$firefox->$name();
		};
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->$name() with no parameters produces a Firefox::Marionette::Exception exception");
	}
	$firefox->sleep_time_in_ms(2_000);
	ok($firefox->find_id($search_box_id)->clear()->find_id($search_box_id)->type('Test::More'), "Sent 'Test::More' to the '$search_box_id' field directly to the element");
	ok($firefox->go("https://metacpan.org/pod/Test::More"), "Just directly going to https://metacpan.org/pod/Test::More");
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
			} elsif ($is_covering) {
			} else {
				$count += 1;
			}
		}
		ok($count == 1, "Downloaded 1 files:$count");
		my $deprecated_handle = $firefox->download($download_path);
		ok($deprecated_handle->isa('GLOB'), "Obtained GLOB from \$firefox->downloaded('$download_path')");
		my $handle = $firefox->downloaded($download_path);
		ok($handle->isa('GLOB'), "Obtained GLOB from \$firefox->downloaded('$download_path')");
		my $gz = Compress::Zlib::gzopen($handle, 'rb') or die "Failed to open gzip stream";
		my $bytes_read = 0;
		while($gz->gzread(my $buffer, 4096)) {
			$bytes_read += length $buffer
		}
		ok($bytes_read > 1_000, "Downloaded file is gzipped");
	}
	foreach my $element ($firefox->find_tag('option')) {
		my $inner_html;
		eval {
			$inner_html = $element->property('innerHTML');
		};
		if ((defined $inner_html) && ($inner_html eq 'Jump to version')) {
			$firefox->script('arguments[0].selected = true', args => $element);
			ok($element->is_selected(), "\$firefox->is_selected() returns true for a selected item");
			$firefox->script('arguments[0].disabled = true', args => $element);
			ok(!$element->is_enabled(), "After script disabled element, \$firefox->is_enabled() correctly reflects disabling");
		}
	}
	$firefox->go('https://metacpan.org');
	ok(!exists $INC{'Keys.pm'}, "Firefox::Marionette::Keys is not loaded");
	eval { require Firefox::Marionette::Keys; };
	ok($@ eq '', "Successfully loaded Firefox::Marionette::Keys");
	Firefox::Marionette::Keys->import(qw(:all));
	ok(CANCEL() eq chr 0xE001, "CANCEL() is correct as 0xE001");
	ok(HELP() eq chr 0xE002, "HELP() is correct as OxE002");
	ok(BACKSPACE() eq chr 0xE003, "BACKSPACE() is correct as OxE003");
	ok(TAB() eq chr 0xE004, "TAB() is correct as OxE004");
	ok(CLEAR() eq chr 0xE005, "CLEAR() is correct as OxE005");
	ok(ENTER() eq chr 0xE006, "ENTER() is correct as OxE006");
	ok(SHIFT() eq chr 0xE008, "SHIFT() is correct as OxE008 (Same as SHIFT_LEFT())");
	ok(SHIFT_LEFT() eq chr 0xE008, "SHIFT_LEFT() is correct as OxE008");
	ok(CONTROL() eq chr 0xE009, "CONTROL() is correct as OxE009 (Same as CONTROL_LEFT())");
	ok(CONTROL_LEFT() eq chr 0xE009, "CONTROL_LEFT() is correct as OxE009");
	ok(ALT() eq chr 0xE00A, "ALT() is correct as OxE00A (Same as ALT_LEFT())");
	ok(ALT_LEFT() eq chr 0xE00A, "ALT_LEFT() is correct as OxE00A");
	ok(PAUSE() eq chr 0xE00B, "PAUSE() is correct as OxE00B");
	ok(ESCAPE() eq chr 0xE00C, "ESCAPE() is correct as OxE00C");
	ok(SPACE() eq chr 0xE00D, "SPACE() is correct as OxE00D");
	ok(PAGE_UP() eq chr 0xE00E, "PAGE_UP() is correct as OxE00E");
	ok(PAGE_DOWN() eq chr 0xE00F, "PAGE_DOWN() is correct as OxE00F");
	ok(END_KEY() eq chr 0xE010, "END_KEY() is correct as OxE010");
	ok(HOME() eq chr 0xE011, "HOME() is correct as OxE011");
	ok(ARROW_LEFT() eq chr 0xE012, "ARROW_LEFT() is correct as OxE012");
	ok(ARROW_UP() eq chr 0xE013, "ARROW_UP() is correct as OxE013");
	ok(ARROW_RIGHT() eq chr 0xE014, "ARROW_UP() is correct as OxE014");
	ok(ARROW_DOWN() eq chr 0xE015, "ARROW_DOWN() is correct as OxE015");
	ok(INSERT() eq chr 0xE016, "INSERT() is correct as OxE016");
	ok(DELETE() eq chr 0xE017, "DELETE() is correct as OxE017");
	ok(F1() eq chr 0xE031, "F1() is correct as OxE031");
	ok(F2() eq chr 0xE032, "F2() is correct as OxE032");
	ok(F3() eq chr 0xE033, "F3() is correct as OxE033");
	ok(F4() eq chr 0xE034, "F4() is correct as OxE034");
	ok(F5() eq chr 0xE035, "F5() is correct as OxE035");
	ok(F6() eq chr 0xE036, "F6() is correct as OxE036");
	ok(F7() eq chr 0xE037, "F7() is correct as OxE037");
	ok(F8() eq chr 0xE038, "F8() is correct as OxE038");
	ok(F9() eq chr 0xE039, "F9() is correct as OxE039");
	ok(F10() eq chr 0xE03A, "F10() is correct as OxE03A");
	ok(F11() eq chr 0xE03B, "F11() is correct as OxE03B");
	ok(F12() eq chr 0xE03C, "F12() is correct as OxE03C");
	ok(META() eq chr 0xE03D, "META() is correct as OxE03D (Same as META_LEFT())");
	ok(META_LEFT() eq chr 0xE03D, "META_LEFT() is correct as OxE03D");
	ok(ZENKAKU_HANKAKU() eq chr 0xE040, "ZENKAKU_HANKAKU() is correct as OxE040");
	ok(SHIFT_RIGHT() eq chr 0xE050, "SHIFT_RIGHT() is correct as OxE050");
	ok(CONTROL_RIGHT() eq chr 0xE051, "CONTROL_RIGHT() is correct as OxE051");
	ok(ALT_RIGHT() eq chr 0xE052, "ALT_RIGHT() is correct as OxE052");
	ok(META_RIGHT() eq chr 0xE053, "META_RIGHT() is correct as OxE053");
	ok(!exists $INC{'Buttons.pm'}, "Firefox::Marionette::Buttons is not loaded");
	eval { require Firefox::Marionette::Buttons; };
	ok($@ eq '', "Successfully loaded Firefox::Marionette::Buttons");
	Firefox::Marionette::Buttons->import(qw(:all));
	ok(LEFT_BUTTON() == 0, "LEFT_BUTTON() is correct as O");
	ok(MIDDLE_BUTTON() == 1, "MIDDLE_BUTTON() is correct as 1");
	ok(RIGHT_BUTTON() == 2, "RIGHT_BUTTON() is correct as 2");
	my $help_button = $firefox->find_class('keyboard-shortcuts');
	ok($help_button, "Found help button on metacpan.org");
	SKIP: {
		my $perform_ok;
		eval {
			$perform_ok = $firefox->perform(
						$firefox->key_down('h'),
						$firefox->pause(2),
						$firefox->key_up('h'),
						$firefox->mouse_move($help_button),
						$firefox->mouse_down(LEFT_BUTTON()),
						$firefox->pause(1),
						$firefox->mouse_up(LEFT_BUTTON()),
						$firefox->key_down(ESCAPE()),
						$firefox->pause(2),
						$firefox->key_up(ESCAPE()),
					);
		};
		if ((!$perform_ok) && ($major_version < 60)) {
			chomp $@;
			diag("The perform method is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("The perform method is not supported for $major_version.$minor_version.$patch_version", 5);
		}
		ok(ref $perform_ok eq $class, "\$firefox->perform() with a combination of mouse, pause and key actions");
		my $value = $firefox->find('//input[@id="' . $search_box_id . '"]')->property('value');
		ok($value eq 'h', "\$firefox->find('//input[\@id=\"$search_box_id\"]')->property('value') is equal to 'h' from perform method above:$value");
		ok($firefox->perform($firefox->pause(2)), "\$firefox->perform() with a single pause action");
		ok($firefox->perform($firefox->mouse_move(x => 0, y => 0),$firefox->mouse_down(), $firefox->mouse_up()), "\$firefox->perform() with a default mouse button and manual x,y co-ordinates");
		eval {
			$firefox->perform({ type => 'unknown' });
		};
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->perform() throws an exception when passed an unknown action:$@");
		chomp $@;
		ok($@ =~ /[ ]at[ ]t.01\-marionette[.]t[ ]line[ ]\d+$/smx, "Exception shows source and line numbers");
		ok($firefox->release(), "\$firefox->release()");
		if ($major_version >= 106) {
			my $origin = $firefox->find_id($search_box_id);
			ok($firefox->perform($firefox->wheel($origin, deltaY => 500, origin => 'viewport')), "\$firefox->perform() with a wheel action");
		}
	}
	SKIP: {
		if ((!$context) && ($major_version < 50)) {
			chomp $@;
			diag("\$firefox->context is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("\$firefox->context is not supported for $major_version.$minor_version.$patch_version", 2);
		}
		ok($firefox->chrome()->context() eq 'chrome', "Setting and reading context of the browser as 'chrome'");
		ok($firefox->content()->context() eq 'content', "Setting and reading context of the browser as 'content'");
	}
	my $body = $firefox->find("//body");
	my $outer_html = $firefox->script(q{ return arguments[0].outerHTML;}, args => [$body]);
	ok($outer_html =~ /<body/smx, "Correctly passing found elements into script arguments");
	$outer_html = $firefox->script(q{ return arguments[0].outerHTML;}, args => $body);
	ok($outer_html =~ /<body/smx, "Converts a single argument into an array");
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

	SKIP: {
		if ((!$chrome_window_handle_supported) && ($major_version < 50)) {
			diag("\$firefox->current_chrome_window_handle is not supported for $major_version.$minor_version.$patch_version");
			skip("\$firefox->current_chrome_window_handle is not supported for $major_version.$minor_version.$patch_version", 1);
		}
		my $current_chrome_window_handle = $firefox->current_chrome_window_handle();
		if ($major_version < 90) {
			ok($current_chrome_window_handle =~ /^\d+$/, "Returned the current chrome window handle as an integer");
		} else {
			ok($current_chrome_window_handle =~ /^$guid_regex$/smx, "Returned the current chrome window handle as a GUID");
		}
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
	if ($capabilities->browser_name() eq 'firefox') {
		ok($capabilities->browser_version() =~ /^\d+[.]\d+(?:[a]\d+)?([.]\d+)?$/, "\$capabilities->browser_version() is a major.minor.patch version number:" . $capabilities->browser_version());
	} else {
		ok($capabilities->browser_version() =~ /^\d+[.]\d+(?:[a]\d+)?([.]\d+)?([.]\d+)?$/, "\$capabilities->browser_version() (non-firefox) is a major.minor.patch.whatever version number:" . $capabilities->browser_version());
	}
	TODO: {
		local $TODO = ($major_version < 31) ? "\$capabilities->platform_version() may not exist for Firefox versions less than 31" : undef;
		ok(defined $capabilities->platform_version() && $capabilities->platform_version() =~ /\d+/, "\$capabilities->platform_version() contains a number:" . ($capabilities->platform_version() || ''));
	}
	TODO: {
			local $TODO = ($ENV{FIREFOX_HOST} || $^O eq 'cygwin' || $^O eq 'MSWin32') ? "\$capabilities->moz_profiles() can contain shorted profile directory names" : undef;
			ok($capabilities->moz_profile() =~ /firefox_marionette/, "\$capabilities->moz_profile() contains 'firefox_marionette':" . $capabilities->moz_profile());
		}
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
			if (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
				diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
				next;
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
			$firefox->install(q[t/addons/not_exists_] . int(rand(50000)));
		};
		chomp $@;
		ok($@ =~ /Failed[ ]to[ ]find[ ]extension/smx, "\$firefox->install() throws an exception when asked to install a non-existant extension:$@");
		eval {
			$result = $firefox->accept_connections(1);
		};
		SKIP: {
			my $exception = "$@";
			chomp $exception;
			if ((!$result) && ($major_version < 52)) {
				skip("Refusing future connections may not be supported in firefox versions less than 52:$exception", 1);
			}
			ok($result, "Accepting future connections");
			$result = $firefox->accept_connections(0);
			ok($result, "Refusing future connections");
		}
		TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	diag("Starting new firefox for testing JSON from localhost and alerts and extensions");
	($skip_message, $firefox) = start_firefox(0, visible => 0, implicit => 987654, geo => 1);
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
	my $path = 't/addons/borderify/manifest.json';
	if (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
	} else {
		my $install_id;
		my $install_path = Cwd::abs_path($path);
		diag("Original install path is $install_path");
		if ($^O eq 'MSWin32') {
			$install_path =~ s/\//\\/smxg;
		}
		diag("Installing extension from $install_path");
		my $temporary = 1;
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
			if ($ENV{FIREFOX_HOST}) {
			} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
				diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
			} else {
				my $go_path = File::Spec->catfile(Cwd::cwd(), qw(t data iframe.html));
				if ($^O eq 'cygwin') {
					$go_path = $firefox->execute( 'cygpath', '-s', '-m', $go_path );
				}
				$firefox->go("file://$go_path");
				my $actual_border;
				CHECK_BORDER: for my $count ( 1 .. 10 ) {
					$actual_border = $firefox->script(q{return document.body.style.border});
					if ($actual_border =~ /red/smx) {
						last CHECK_BORDER;
					} else {
						sleep 1;
					}
				}
				my $expected_border =  "5px solid red";
				ok($actual_border eq $expected_border, "Extension is proved to be running correctly: '$actual_border' vs '$expected_border'");
			}
			ok($firefox->uninstall($install_id), "Successfully uninstalled an extension");
		}
	}
	if ($ENV{FIREFOX_HOST}) {
	} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
		diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
	} elsif ($major_version >= $min_geo_version) {
		my $new_latitude = -37.123;
		my $new_longitude = 144.456;
		$firefox->geo(latitude => $new_latitude, longitude => $new_longitude);
		my $path = File::Spec->catfile(Cwd::cwd(), qw(t data iframe.html));
		if ($^O eq 'cygwin') {
			$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
		}
		$firefox->go("file://$path");
		if (my $geo5 = $firefox->geo()) {
			my $current_latitude = $geo5->latitude();
			my $current_longitude = $geo5->longitude();
			ok($current_latitude == $new_latitude, "\$geo5->latitude() has changed after a call to \$firefox->geo(latitude => $new_latitude, longitude => $new_longitude):$current_latitude");
			ok($current_longitude == $new_longitude, "\$geo5->longitude() has changed after a call to \$firefox->geo(latitude => $new_latitude, longitude => $new_longitude):$current_longitude");
		} elsif (($uname eq 'cygwin') || ($uname eq 'MSWin32')) {
			diag("Location services may be disabled");
			eval {
				$firefox->dismiss_alert();
			};
		}
	}
	my $daemon = HTTP::Daemon->new(LocalAddr => 'localhost') || die "Failed to create HTTP::Daemon";
	SKIP: {
		if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
			diag("\$capabilities->proxy is not supported for remote hosts");
			skip("\$capabilities->proxy is not supported for remote hosts", 3);
		} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
			diag("\$capabilities->proxy is not supported for remote hosts");
			skip("\$capabilities->proxy is not supported for remote hosts", 3);
		} elsif ($^O eq 'cygwin') {
			diag("\$capabilities->proxy is not supported for " . $^O);
			skip("\$capabilities->proxy is not supported for " . $^O, 3);
		} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
			my $json_document = Encode::decode('UTF-8', '{ "id": "5", "value": "sömething"}');
			my $txt_document = 'This is ordinary text';
			if (my $pid = fork) {
				wait_for_server_on($daemon, $daemon->url(), $pid);
				my $base_url = $daemon->url();
				undef $daemon;
				$firefox->go($base_url . '?format=JSON');
				ok($firefox->strip() eq $json_document, "Correctly retrieved JSON document");
				diag(Encode::encode('UTF-8', $firefox->strip(), 1));
				ok($firefox->json()->{id} == 5, "Correctly parsed JSON document");
				ok(Encode::encode('UTF-8', $firefox->json()->{value}, 1) eq "sömething", "Correctly parsed UTF-8 JSON field");
				$firefox->go($base_url . '?format=txt');
				ok($firefox->strip() eq $txt_document, "Correctly retrieved TXT document");
				diag($firefox->strip());
				if ($major_version >= 61) {
					my $handle = $firefox->download($base_url . '?format=txt');
					my $output = <$handle>;
					ok($output eq $txt_document, "Correctly downloaded TXT document without timeout");
					$handle = $firefox->download($base_url . '?format=txt', 50);
					$output = <$handle>;
					ok($output eq $txt_document, "Correctly downloaded TXT document with explicit timeout");
				}
				while(kill 0, $pid) {
					kill $signals_by_name{TERM}, $pid;
					sleep 1;
					waitpid $pid, POSIX::WNOHANG();
				}
				ok($! == POSIX::ESRCH(), "Process $pid no longer exists:$!");
			} elsif (defined $pid) {
				eval 'Devel::Cover::set_coverage("none")' if $is_covering;
				eval {
					local $SIG{ALRM} = sub { die "alarm during content server\n" };
					alarm 40;
					$0 = "[Test HTTP Content Server for " . getppid . "]";
					diag("Accepting connections for $0");
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
			skip("Firefox $major_version does not appear to support the \$firefox->accept_dialog() method", 1);
		} elsif (($major_version == 78) && ($@) && ($@->isa('Firefox::Marionette::Exception::NoSuchAlert'))) {
			diag("Firefox $major_version has already closed the prompt:$@");
			skip("Firefox $major_version has already closed the prompt", 1);
		}
		ok($accept_dialog, "\$firefox->accept_dialog() accepts the dialog box:$@");
	}
	TODO: {
		local $TODO = $major_version != 60 && $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	if ($ENV{RELEASE_TESTING}) {
		diag("Starting new firefox for testing images and links");
		($skip_message, $firefox) = start_firefox(0, visible => 0, geo => { latitude => 141, longitude => 85, altitude => 40, altitude_accuracy => 20 });
		if (!$skip_message) {
			$at_least_one_success = 1;
		}
		if ($skip_message) {
			skip($skip_message, 8);
		}
		ok($firefox, "Firefox has started in Marionette mode with visible set to 0");
		my $daemon = HTTP::Daemon->new(LocalAddr => 'localhost') || die "Failed to create HTTP::Daemon";
		SKIP: {
			if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
				diag("\$capabilities->proxy is not supported for remote hosts");
				skip("\$capabilities->proxy is not supported for remote hosts", 3);
			} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
				diag("\$capabilities->proxy is not supported for remote hosts");
				skip("\$capabilities->proxy is not supported for remote hosts", 3);
			} elsif ($^O eq 'cygwin') {
				diag("\$capabilities->proxy is not supported for " . $^O);
				skip("\$capabilities->proxy is not supported for " . $^O, 3);
			} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
				if (my $pid = fork) {
					wait_for_server_on($daemon, $daemon->url(), $pid);
					my $base_url = $daemon->url();
					undef $daemon;
					$firefox->go($base_url . '?links_and_images');
					foreach my $image ($firefox->images()) {
						ok($image->tag(), "Image tag is defined as " . $image->tag());
					}
					foreach my $link ($firefox->links()) {
						if (defined $link->text()) {
							ok(defined $link->text(), "Link text is defined as " . $link->text());
						} else {
							ok(1, "Link text is not defined");
						}
					}
					while(kill 0, $pid) {
						kill $signals_by_name{TERM}, $pid;
						sleep 1;
						waitpid $pid, POSIX::WNOHANG();
					}
					ok($! == POSIX::ESRCH(), "Process $pid no longer exists:$!");
				} elsif (defined $pid) {
					eval 'Devel::Cover::set_coverage("none")' if $is_covering;
					eval {
						local $SIG{ALRM} = sub { die "alarm during links and images server\n" };
						alarm 40;
						$0 = "[Test HTTP Links and Images Server for " . getppid . "]";
						diag("Accepting connections for $0");
						while (my $connection = $daemon->accept()) {
							diag("Accepted connection");
							if (my $child = fork) {
								waitpid $child, 0;
							} elsif (defined $child) {
								eval {
									local $SIG{ALRM} = sub { die "alarm during links and images server accept\n" };
									alarm 40;
									if (my $request = $connection->get_request()) {
										diag("Got request (pid: $$) for " . $request->uri());
										my ($headers, $response);
										if ($request->uri() =~ /image[.]png/) {
											$headers = HTTP::Headers->new('Content-Type', 'image/png');
											$response = HTTP::Response->new(200, "OK", $headers, MIME::Base64::decode_base64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQImWP48Gr6fwAIsANxwk14sgAAAABJRU5ErkJggg=="));
										} else {
											$headers = HTTP::Headers->new('Content-Type', 'text/html');
											$response = HTTP::Response->new(200, "OK", $headers, '<!DOCTYPE html><html lang="en-AU"><head><title>Test</title><meta/></head><body><form action="/submit"><input type="image" alt="no idea" src="/image.png"></form><a href="http://example.com/"></a></body></html>');
										}
										$connection->send_response($response);
									}
									$connection->close;
									diag("Connection closed (pid: $$)");
									$connection = undef;
									exit 0;
								} or do {
									chomp $@;
									diag("Caught exception in links and images server accept:$@");
								};
								diag("Connection error");
								exit 1;
							} else {
								diag("Failed to fork connection:$!");
								die "Failed to fork:$!";
							}
						}
					} or do {
						chomp $@;
						diag("Caught exception in links and images server:$@");
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
		TODO: {
			local $TODO = $major_version != 60 && $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
			ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
		}
	}
}

sub display_name {
	my ($certificate) = @_;
	return $certificate->display_name() || $certificate->nickname();
}

sub stringify_scroll_arguments {
	my (@scroll_arguments) = @_;
	if (@scroll_arguments) {
		if (ref $scroll_arguments[0]) {
			my @attributes;
			while (my ($key, $value) = each %{$scroll_arguments[0]}) {
				push @attributes, "$key => '$value'";
			}
			return '{' . (join q[, ], @attributes) . '}';
		} else {
			return $scroll_arguments[0];
		}
	} else {
		return q[an empty list];
	}
}

sub test_scroll_arguments {
	my ($number_of_links) = @_;
	my $number_of_options = 5;
	if (($number_of_links % $number_of_options) == 0) {
		return ();
	} elsif (($number_of_links % $number_of_options) == 1) {
		return (1);
	} elsif (($number_of_links % $number_of_options) == 2) {
		return (0);
	} elsif (($number_of_links % $number_of_options) == 3) {
		return ({block => 'end'});
	} elsif (($number_of_links % $number_of_options) == 4) {
		return ({behavior => 'smooth', block => 'end', inline => 'nearest'});
	} else {
		return ();
	}
}

SKIP: {
	if ($bad_network_behaviour) {
		diag("Skipping proxy by argument, capabilities, window switching and certificates tests because these tests fail when metacpan connections are re-routed above");
		skip("Skipping proxy by argument, capabilities, window switching and certificates tests because these tests fail when metacpan connections are re-routed above", 32);
	}
	my $proxyPort = empty_port();
	diag("Starting new firefox for testing proxy by argument, capabilities, window switching and certificates using proxy port TCP/$proxyPort");
	my $proxy_host = 'localhost:' . $proxyPort;
	if ($major_version == 38) {
		skip("Skipping b/c proxy must be undefined", 32);
	}
	if ($major_version >= 135) {
		skip("Skipping b/c proxy seems to cause hangs", 32);
	}
	($skip_message, $firefox) = start_firefox(1, insecure => 0, import_profile_paths => [ 't/data/logins.json', 't/data/key4.db' ], manual_certificate_add => 1, console => 1, debug => 0, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 0, page_load_strategy => 'none', moz_webdriver_click => 0, moz_accessibility_checks => 0, proxy => Firefox::Marionette::Proxy->new(host => $proxy_host)), timeouts => Firefox::Marionette::Timeouts->new(page_load => 78_901, script => 76_543, implicit => 34_567));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 32);
	}
	ok($firefox, "Firefox has started in Marionette mode with definable capabilities set to different values");
	my $profile_directory = $firefox->profile_directory();
	ok($profile_directory, "\$firefox->profile_directory() returns $profile_directory");
	my $possible_logins_path = File::Spec->catfile($profile_directory, 'logins.json');
	unless ($ENV{FIREFOX_HOST}) {
		ok(-e $possible_logins_path, "There is a (imported) logins.json file in the profile directory");
	}
	if ($major_version > 56) {
		ok(scalar $firefox->logins() == 1, "\$firefox->logins() shows the correct number (1) of records (including recent import):" . scalar $firefox->logins());
	}
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
		ok($capabilities->proxy()->http() eq "$proxy_host", "\$capabilities->proxy()->http() is '$proxy_host'");
		ok($capabilities->proxy()->https() eq "$proxy_host", "\$capabilities->proxy()->https() is '$proxy_host'");
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
		} elsif ($ENV{FIREFOX_NO_VISIBLE}) {
			diag("\$capabilities->headless is forced on for FIREFOX_NO_VISIBLE testing");
			skip("\$capabilities->headless is forced on for FIREFOX_NO_VISIBLE testing", 1);
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
		if ($major_version >= 121) {
			my $initial_url = $firefox->script("return window.location.href");
			my $script_window = $firefox->script("return window");
			ok($script_window eq $new_window, "\$firefox->script(\"return window\") matches \$firefox->new_window() output");
			my $argument_url = $firefox->script("return arguments[0].location.href", args => [ $script_window ]);
			ok($argument_url eq $initial_url, "window object can be used as an in and out parameter for javascript calls:$argument_url:$initial_url");
		}
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
	my $certificate = Firefox::Marionette::Certificate->new();
	ok(!$certificate->is_server_cert(), "Firefox::Marionette::Certificate->new() does not produce a server cert (test coverage)");
	my @certificates;
	eval { @certificates = $firefox->certificates(); };
	SKIP: {
		if ((scalar @certificates == 0) && ($major_version < 50)) {
			chomp $@;
			diag("\$firefox->certificates is not supported for $major_version.$minor_version.$patch_version:$@");
			skip("\$firefox->certificates is not supported for $major_version.$minor_version.$patch_version", 57);
		}
		my $count = 0;
		foreach my $certificate (sort { display_name($a) cmp display_name($b) } $firefox->certificates()) {
			if ($firefox->is_trusted($certificate)) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is trusted in the current profile");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT trusted in the current profile");
			}
		}
		eval { $firefox->add_certificate( ) };
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->add_certificate(path => \$value) throws an exception if nothing is added");
		eval { $firefox->add_certificate( path => '/this/does/not/exist' ) };
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->add_certificate(path => \$value) throws an exception if a non existent file is added");
		eval { $firefox->add_certificate( string => 'this is nonsense' ); };
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->add_certificate(string => \$value) throws an exception if nonsense is added");
		my $handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_part_cert_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
		$handle->print(<<'_CERT_') or die "Failed to write to temporary file:$!";
-----BEGIN CERTIFICATE-----
MIIFsDC
_CERT_
		seek $handle, 0, 0 or Carp::croak("Failed to seek to start of temporary file:$!");
		eval { $firefox->add_certificate( path => $handle->filename() ); };
		ok(ref $@ eq 'Firefox::Marionette::Exception', "\$firefox->add_certificate(string => \$value) throws an exception if partial certificate is added");
		if (defined $ca_cert_handle) {
			ok($firefox->add_certificate(path => $ca_cert_handle->filename(), trust => ',,,'), "Adding a certificate with no permissions");
		}
		$count = 0;
		foreach my $certificate (sort { display_name($a) cmp display_name($b) } $firefox->certificates()) {
			ok($certificate, "Found the " . Encode::encode('UTF-8', display_name($certificate)) . " from the certificate database");
			ok($firefox->certificate_as_pem($certificate) =~ /BEGIN[ ]CERTIFICATE.*MII.*END[ ]CERTIFICATE\-+\s$/smx, Encode::encode('UTF-8', display_name($certificate)) . " looks like a PEM encoded X.509 certificate");
			my $delete_class;
			eval {
				$delete_class = $firefox->delete_certificate($certificate);
			} or do {
				diag("\$firefox->delete_certificate() threw exeception:$@");
			};
			if (($ENV{RELEASE_TESTING}) || (defined $delete_class)) {
				ok(ref $delete_class eq $class, "Deleted " . Encode::encode('UTF-8', display_name($certificate)) . " from the certificate database");
			}
			if ($certificate->is_ca_cert()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is a CA cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT a CA cert");
			}
			if ($certificate->is_any_cert()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is any cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT any cert");
			}
			if ($certificate->is_unknown_cert()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is an unknown cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT an unknown cert");
			}
			if ($certificate->is_built_in_root()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is a built in root cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT a built in root cert");
			}
			if ($certificate->is_server_cert()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is a server cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT a server cert");
			}
			if ($certificate->is_user_cert()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is a user cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT a user cert");
			}
			if ($certificate->is_email_cert()) {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is an email cert");
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " is NOT an email cert");
			}
			ok($certificate->issuer_name(), Encode::encode('UTF-8', display_name($certificate)) . " has an issuer_name of " . Encode::encode('UTF-8', $certificate->issuer_name()));
			if ($major_version > 52) {
				if (defined $certificate->nickname()) {
					ok($certificate->nickname(), Encode::encode('UTF-8', display_name($certificate)) . " has a nickname of " . $certificate->nickname());
				} else {
					ok(1, Encode::encode('UTF-8', display_name($certificate)) . " does not have a specified nickname");
				}
			}
			ok(defined $certificate->common_name(), Encode::encode('UTF-8', display_name($certificate)) . " has a common_name of " . Encode::encode('UTF-8', $certificate->common_name()));
			if (defined $certificate->email_address()) {
				ok($certificate->email_address(), Encode::encode('UTF-8', display_name($certificate)) . " has an email_address of " . $certificate->email_address());
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " does not have a specified email_address");
			}
			ok($certificate->sha256_subject_public_key_info_digest(), Encode::encode('UTF-8', display_name($certificate)) . " has a sha256_subject_public_key_info_digest of " . $certificate->sha256_subject_public_key_info_digest());
			ok(defined $certificate->issuer_organization(), Encode::encode('UTF-8', display_name($certificate)) . " has an issuer_organization of " . Encode::encode('UTF-8', $certificate->issuer_organization()));
			ok($certificate->db_key(), Encode::encode('UTF-8', display_name($certificate)) . " has a db_key of " . $certificate->db_key());
			ok($certificate->token_name(), Encode::encode('UTF-8', display_name($certificate)) . " has a token_name of " . Encode::encode('UTF-8', $certificate->token_name()));
			if (defined $certificate->sha256_fingerprint()) {
				ok($certificate->sha256_fingerprint(), Encode::encode('UTF-8', display_name($certificate)) . " has a sha256_fingerprint of " . $certificate->sha256_fingerprint());
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . ' does not have a sha256_fingerprint');
			}
			ok($certificate->subject_name(), Encode::encode('UTF-8', display_name($certificate)) . " has a subject_name of " . Encode::encode('UTF-8', $certificate->subject_name()));
			if (defined $certificate->key_usages()) {
				ok(defined $certificate->key_usages(), Encode::encode('UTF-8', display_name($certificate)) . " has a key_usages of " . $certificate->key_usages());
			} else {
				ok(1, Encode::encode('UTF-8', display_name($certificate)) . " does not has a key_usage");
			}
			ok(defined $certificate->issuer_organization_unit(), Encode::encode('UTF-8', display_name($certificate)) . " has an issuer_organization_unit of " . Encode::encode('UTF-8', $certificate->issuer_organization_unit()));
			{
				local $TODO = "Firefox can neglect old certificates.  See https://bugzilla.mozilla.org/show_bug.cgi?id=1710716";
				ok($certificate->not_valid_after() > time, Encode::encode('UTF-8', display_name($certificate)) . " has a current not_valid_after value of " . localtime $certificate->not_valid_after());
			}
			ok($certificate->not_valid_before() < $certificate->not_valid_after(), Encode::encode('UTF-8', display_name($certificate)) . " has a not_valid_before that is before the not_valid_after value");
			ok($certificate->not_valid_before() < time, Encode::encode('UTF-8', display_name($certificate)) . " has a current not_valid_before value of " . localtime $certificate->not_valid_before());
			ok($certificate->serial_number(), Encode::encode('UTF-8', display_name($certificate)) . " has a serial_number of " . $certificate->serial_number());
			ok(defined $certificate->issuer_common_name(), Encode::encode('UTF-8', display_name($certificate)) . " has a issuer_common_name of " . Encode::encode('UTF-8', $certificate->issuer_common_name()));
			ok(defined $certificate->organization(), Encode::encode('UTF-8', display_name($certificate)) . " has a organization of " . Encode::encode('UTF-8', $certificate->organization()));
			ok($certificate->sha1_fingerprint(), Encode::encode('UTF-8', display_name($certificate)) . " has a sha1_fingerprint of " . $certificate->sha1_fingerprint());
			ok(defined $certificate->organizational_unit(), Encode::encode('UTF-8', display_name($certificate)) . " has a organizational_unit of " . Encode::encode('UTF-8', $certificate->organizational_unit()));
			$count += 1;
			if (!$ENV{RELEASE_TESTING}) {
				last;
			}
		}
		if ($ENV{RELEASE_TESTING}) {
			ok($count > 0, "There are $count certificates in the firefox database");
		}
	}
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

sub check_for_window {
	my ($firefox, $window_handle) = @_;
	if (defined $window_handle) {
		foreach my $existing_handle ($firefox->window_handles()) {
			if ($major_version < 90) {
				if ($existing_handle == $window_handle) {
					return 1;
				}
			} else {
				if ($existing_handle eq $window_handle) {
					return 1;
				}
			} 
		}
	}
	return 0;
}

my $maximise;
SKIP: {
	diag("Starting new firefox for testing \%ENV proxy, min/maxing and killing firefox");
	local %ENV = %ENV;
	my $proxyHttpPort = empty_port();
	my $proxyHttpsPort = empty_port();
	my $proxyFtpPort = empty_port();
	if ($major_version == 38) {
	} else {
		$ENV{http_proxy} = 'http://localhost:' . $proxyHttpPort;
		$ENV{https_proxy} = 'http://localhost:' . $proxyHttpsPort;
		$ENV{ftp_proxy} = 'ftp://localhost:' . $proxyFtpPort;
	}
	if ($major_version >= 135) {
		skip("Skipping b/c proxy seems to cause hangs", 15);
	}
	($skip_message, $firefox) = start_firefox(1, addons => 1, visible => 1, width => 800, height => 600);
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
		local $TODO = $uname eq 'linux' ? '' : "Initial width/height parameters not entirely stable in $uname";
		ok($window_rect->width() >= 800, "Window has a width of 800 (" . $window_rect->width() . ")");
		ok($window_rect->height() >= 600, "Window has a height of 600 (" . $window_rect->height() . ")");
		if (($window_rect->width() >= 800) && ($window_rect->height() >= 600)) {
		} else {
			diag("Width/Height for $uname set to 800x600, but returned " . $window_rect->width() . "x" . $window_rect->height());
		}
	}
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	if ($ENV{FIREFOX_HOST}) {
		diag("\$capabilities->headless is forced on for FIREFOX_HOST testing");
	} elsif ($ENV{FIREFOX_NO_VISIBLE}) {
		diag("\$capabilities->headless is forced on for FIREFOX_NO_VISIBLE testing");
	} else {
		ok(!$capabilities->moz_headless(), "\$capabilities->moz_headless() is set to false");
	}
	diag("Final Browser version is " . $capabilities->browser_version());
	if ($major_version >= 51) {
		SKIP: {
			my $webgl2 = $firefox->script(q[return document.createElement('canvas').getContext('webgl2') ? true : false;]);
			my $experimental = $firefox->script(q[return document.createElement('canvas').getContext('experimental-webgl') ? true : false;]);
			my $other = $firefox->script(q[return ("WebGLRenderingContext" in window) ? true : false;]);
			my $webgl_ok = 1;
			if ($webgl2) {
				diag("WebGL (webgl2) is working correctly for " . $capabilities->browser_version() . " on $uname");
			} elsif ($experimental) {
				diag("WebGL (experimental) is working correctly for " . $capabilities->browser_version() . " on $uname");
			} elsif ($other) {
				diag("WebGL (WebGLRenderingContext) is providing some sort of support for " . $capabilities->browser_version() . " on $uname");
			} elsif (($^O eq 'cygwin') ||
				($^O eq 'darwin') ||
				($^O eq 'MSWin32'))
			{
				$webgl_ok = 0;
				diag("WebGL is NOT working correctly for " . $capabilities->browser_version() . " on $uname");
			} else {
				my $glxinfo = `glxinfo 2>&1`;
				$glxinfo =~ s/\s+/ /smxg;
				if ($? == 0) {
					if ($glxinfo =~ /^Error:/smx) {
						diag("WebGL is NOT working correctly for " . $capabilities->browser_version() . " on $uname, probably because glxinfo has failed:$glxinfo");
					} else {
						$webgl_ok = 0;
						diag("WebGL is NOT working correctly for " . $capabilities->browser_version() . " on $uname but glxinfo has run successfully:$glxinfo");
					}
				} else {
					$webgl_ok = 0;
					diag("WebGL is NOT working correctly for " . $capabilities->browser_version() . " on $uname and glxinfo cannot be run:$?");
				}
			}
			ok($webgl_ok, "WebGL is enabled when visible and addons are turned on");
		}
	}
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'manual', "\$capabilities->proxy()->type() is 'manual'");
		ok($capabilities->proxy()->http() eq 'localhost:' . $proxyHttpPort, "\$capabilities->proxy()->http() is 'localhost:$proxyHttpPort':" . $capabilities->proxy()->http());
		ok($capabilities->proxy()->https() eq 'localhost:' . $proxyHttpsPort, "\$capabilities->proxy()->https() is 'localhost:$proxyHttpsPort'");
		if ($major_version < 90) {
			ok($capabilities->proxy()->ftp() eq 'localhost:' . $proxyFtpPort, "\$capabilities->proxy()->ftp() is 'localhost:$proxyFtpPort'");
		}
	}
	SKIP: {
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
	if ($ENV{FIREFOX_HOST}) {
		SKIP: {
			skip("Not testing dead firefox processes with ssh", 2);	
		}
		TODO: {
			local $TODO = $correct_exit_status == 0 ? q[] : $capabilities->browser_version() . " is not exiting cleanly";
			ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
		}
	} elsif (($^O eq 'MSWin32') || (!grep /^moz_process_id$/, $capabilities->enumerate())) {
		SKIP: {
			skip("Not testing dead firefox processes for win32/early firefox versions", 2);	
		}
		TODO: {
			local $TODO = $correct_exit_status == 0 ? q[] : $capabilities->browser_version() . " is not exiting cleanly";
			ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
		}
	} elsif ($^O eq 'cygwin') {
		SKIP: {
			skip("Not testing dead firefox processes for cygwin", 2);	
		}
		TODO: {
			local $TODO = $correct_exit_status == 0 ? q[] : $capabilities->browser_version() . " is not exiting cleanly";
			ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
		}
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
	diag("Starting new firefox for testing visibility and TLS proxy servers");
	my $proxyPort = empty_port();
	my $proxy_host = 'localhost:' . $proxyPort;
	if ($major_version == 45) {
		skip("Skipping b/c of proxy setCharPref exceptions", 1);
	}
	if ($major_version == 38) {
		skip("Skipping b/c proxy must be undefined", 1);
	}
	if ($major_version >= 135) {
		skip("Skipping b/c proxy seems to cause hangs", 1);
	}
	($skip_message, $firefox) = start_firefox(1, visible => 1, width => 800, height => 600,capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 0, proxy => Firefox::Marionette::Proxy->new(tls => $proxy_host)));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 451);
	}
	ok($firefox, "Firefox has started in Marionette mode with visible set to 1");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'pac', "\$capabilities->proxy()->type() is 'pac'");
		ok($capabilities->proxy()->pac() =~ /^data:text\/plain,function(?:[ ]|%20)FindProxyForURL[(][)](?:[{]|%7B)return(?:[ ]|%20)(?:"|%22)HTTPS(?:[ ]|%20)localhost:$proxyPort(?:"|%22)(?:[}]|%7D)$/smx, qq[\$capabilities->proxy()->pac() is 'data:text/plain,function FindProxyForURL(){return "HTTPS localhost:$proxyPort"}':] . $capabilities->proxy()->pac());
	}
	if ($major_version < 52) {
		diag("Not attempting to resize for Firefox $major_version");
	} elsif ($maximise) {
		local $TODO = q[];
		my $count = 0;
		my $resize_works;
		foreach my $display ($firefox->displays()) {
			$count += 1;
			ok(defined $display->usage(), "\$display->usage() is defined:" . $display->usage());
			ok(defined $display->designation(), "\$display->designation() is defined:" . $display->designation());
			ok($display->sar() =~ /^\d+(?:[.]\d+)?:\d+$/smx, "\$display->sar() is a ratio:" . $display->sar());
			ok($display->dar() =~ /^\d+(?:[.]\d+)?(?::\d+)?$/smx, "\$display->dar() is a ratio or a floating point number:" . $display->dar());
			ok($display->par() =~ /^\d+(?:[.]\d+)?(?::\d+(?:[.]\d+)?)?$/smx, "\$display->par() is a ratio or a floating point number:" . $display->par());
			my $result;
			eval {
				$result = $firefox->resize($display->width(), $display->height());
				$resize_works = 1;
			} or do {
				if ($major_version < 60) {
					chomp $@;
					diag("Failed to resize browser for old browser version $major_version:$@");
				} else {
					ok(0, "Failed to resize browser for a modern browser:$@");
					diag("Failed to resize browser for a modern browser:$@");
				}
			};
			if ($result) {
				ok(1, "Resized the display to " . $display->width . "x" . $display->height());
				last unless ($ENV{RELEASE_TESTING});
			} else {
				ok(1, "Not able to resize the display to " . $display->width . "x" . $display->height());
			}
		}
		ok($count, "$count displays are currently known to firefox");
		my $iphone_count = 0;
		foreach my $display ($firefox->displays(qr/iphone/smxi)) {
			$iphone_count += 1;
			ok($display->usage() =~ /iphone/smxi, "iPhone display detected:" . $display->usage());
		}
		ok($iphone_count, "$iphone_count displays are for an iphone");
		ok($firefox->displays(qr/iphone/i) < $firefox->displays(), "There are fewer displays for iphones than all displays");
		if ($ENV{FIREFOX_HOST}) {
		} elsif (($^O eq 'openbsd') && (Cwd::cwd() !~ /^($quoted_home_directory\/Downloads|\/tmp)/)) {
			diag("Skipping checks that use a file:// url b/c of OpenBSD's unveil functionality - see https://bugzilla.mozilla.org/show_bug.cgi?id=1580271");
		} elsif ($major_version >= $min_geo_version) {
			my $path = File::Spec->catfile(Cwd::cwd(), qw(t data visible.html));
			if ($^O eq 'cygwin') {
				$path = $firefox->execute( 'cygpath', '-s', '-m', $path );
			}
			my $url = "file://$path";
			ok($firefox->go($url), "$url has been loaded");
			my $element = $firefox->find_id('username');
			if (($resize_works) && ($firefox->resize(800, 600))) {
				my $percentage = $firefox->percentage_visible($element);
				ok($percentage == 0, "Percentage visible is 0% for the username field:$percentage");
				if ($major_version >= 59) {
					ok($firefox->scroll($element, { block => 'center' }), "Scroll until the username field is in the center of the screen");
					$percentage = $firefox->percentage_visible($element);
					ok($percentage > 90, "Percentage visible is greater than 90% for the username field:$percentage"); # should be 100% but weird things happen apparently
				}
			} else {
				diag("Skipping checks that require resize to work");
			}
		}
	}
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	diag("Starting new firefox for shortcut TLS proxy servers");
	my $proxyPort = empty_port();
	my $proxy_host = 'localhost:' . $proxyPort;
	if (($major_version == 45) || ($major_version == 38)) {
		skip("Skipping b/c of segmentation faults for proxy capabilities", 5);
	}
	if (($uname eq 'cygwin') || ($uname eq 'MSWin32')) {
		skip("Skipping b/c of hangs in Windows 11 with recent firefox (>= 135) for proxy capabilities", 5);
	}
	if ($major_version >= 135) {
		skip("Skipping b/c proxy seems to cause hangs", 5);
	}
	($skip_message, $firefox) = start_firefox(0, capabilities => Firefox::Marionette::Capabilities->new(moz_headless => 0, page_load_strategy => 'none', proxy => Firefox::Marionette::Proxy->new(host => $proxy_host)), proxy => "https://$proxy_host");
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 5);
	}
	ok($firefox, "Firefox has started in Marionette mode with visible set to 0");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!grep /^page_load_strategy$/, $capabilities->enumerate()) {
			diag("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->page_load_strategy is not supported for " . $capabilities->browser_version(), 1);
		}
		ok($capabilities->page_load_strategy() eq 'none', "\$capabilities->page_load_strategy() is 'none'");
	}
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'pac', "\$capabilities->proxy()->type() is 'pac'");
		ok($capabilities->proxy()->pac() =~ /^data:text\/plain,function(?:[ ]|%20)FindProxyForURL[(][)](?:[{]|%7B)return(?:[ ]|%20)(?:"|%22)HTTPS(?:[ ]|%20)$proxy_host(?:"|%22)(?:[}]|%7D)$/smx, qq[\$capabilities->proxy()->pac() is 'data:text/plain,function FindProxyForURL(){return "HTTPS $proxy_host"}':] . $capabilities->proxy()->pac());
	}
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	diag("Starting new firefox for shortcut normal proxy servers");
	my $proxyPort = empty_port();
	my $proxy_host = 'localhost:' . $proxyPort;
	if ($major_version == 38) {
		skip("Skipping b/c of segmentation faults for proxy capabilities", 5);
	}
	if (($uname eq 'cygwin') || ($uname eq 'MSWin32')) {
		skip("Skipping b/c of hangs in Windows 11 with recent firefox (>= 135) for proxy capabilities", 5);
	}
	if ($major_version >= 135) {
		skip("Skipping b/c proxy seems to cause hangs", 5);
	}
	($skip_message, $firefox) = start_firefox(0, proxy => URI::URL->new("http://$proxy_host"));
	if (!$skip_message) {
		$at_least_one_success = 1;
	}
	if ($skip_message) {
		skip($skip_message, 5);
	}
	ok($firefox, "Firefox has started in Marionette mode with visible set to 0");
	my $capabilities = $firefox->capabilities();
	ok((ref $capabilities) eq 'Firefox::Marionette::Capabilities', "\$firefox->capabilities() returns a Firefox::Marionette::Capabilities object");
	SKIP: {
		if (!$capabilities->proxy()) {
			diag("\$capabilities->proxy is not supported for " . $capabilities->browser_version());
			skip("\$capabilities->proxy is not supported for " . $capabilities->browser_version(), 4);
		}
		ok($capabilities->proxy()->type() eq 'manual', "\$capabilities->proxy()->type() is 'manual'");
		ok($capabilities->proxy()->http() eq $proxy_host, "\$capabilities->proxy()->http() is '$proxy_host':" . $capabilities->proxy()->http());
		ok($capabilities->proxy()->https() eq $proxy_host, "\$capabilities->proxy()->https() is '$proxy_host'");
	}
	TODO: {
		local $TODO = $correct_exit_status == 0 ? q[] : "$version_string is not exiting cleanly";
		ok($firefox->quit() == $correct_exit_status, "Firefox has closed with an exit status of $correct_exit_status:" . $firefox->child_error());
	}
}

SKIP: {
	if ($major_version > 138) {
		($skip_message, $firefox) = start_firefox(0, system_access => 0);
		if (!$skip_message) {
			$at_least_one_success = 1;
		}
		if ($skip_message) {
			skip($skip_message, 5);
		}
		ok($firefox->content(), "\$firefox->content() is called to prove we are okay");
		eval {
			$firefox->chrome();
		};
		chomp $@;
		ok($@, "Unable to move to chrome mode when system_access is turned off:$@");
		ok($firefox->quit() == 0, "Firefox has closed with an exit status of 0:" . $firefox->child_error());
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
	my $argument_string = q[];
	if ($ENV{FIREFOX_VISIBLE}) {
		$argument_string = q[visible => 1];
	}
	my $exit_status = system { $^X } $^X, (map { "-I$_" } @INC), '-MFirefox::Marionette', '-e', "my \$f = Firefox::Marionette->new($argument_string); exit 0";
	ok($exit_status == 0, "Firefox::Marionette doesn't alter the exit code of the parent process if it isn't closed cleanly");
	$exit_status = system { $^X } $^X, (map { "-I$_" } @INC), '-MFirefox::Marionette', '-e', "my \$f = Firefox::Marionette->new($argument_string); \$f = undef; exit 0";
	ok($exit_status == 0, "Firefox::Marionette doesn't alter the exit code of the parent process if it is 'undefed'");
	if ($ENV{RELEASE_TESTING}) {
		if ($ENV{FIREFOX_HOST}) {
			my $user = getpwuid($>);;
			my $host = $ENV{FIREFOX_HOST};
			if ($ENV{FIREFOX_USER}) {
				$user = $ENV{FIREFOX_USER};
			} elsif (($ENV{FIREFOX_HOST} eq 'localhost') && (!$ENV{FIREFOX_PORT})) {
				$user = 'firefox';
			}
			my $handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_ssh_local_directory_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
			fcntl $handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
			my $via = $ENV{FIREFOX_VIA} ? q[, via => "] . $ENV{FIREFOX_VIA} . q["] : q[];
			my $handle_fileno = fileno $handle;
			my $command = join q[ ], $^X, (map { "-I$_" } @INC), '-MFirefox::Marionette', '-e', q['open(my $fh, ">&=", ] . $handle_fileno . q[) or die "OPEN:$!"; $f = Firefox::Marionette->new( user => "] . $user . q[", host => "] . $host . q["] . $via . ($argument_string ? ", $argument_string" : q[]) . q[); $fh->print($f->ssh_local_directory()) or die "PRINT:$!"; close($fh) or die "CLOSE:$!";'];
			$command =~ s/([@])/\\$1/smxg;
			my $output = `$command`;
			$handle->seek(0,0) or die "Failed to seek on temporary file:$!";
			my $result = read($handle, my $directory, 2048) or die "Failed to read from temporary file:$!";
			ok(!-d $directory, "Firefox::Marionette->new() cleans up the ssh local directory at $directory");
		} else {
			my $command = join q[ ], $^X, (map { "-I$_" } @INC), '-MFirefox::Marionette', '-e', qq['\$f = Firefox::Marionette->new($argument_string); print \$f->root_directory();'];
			my $directory = `$command`;
			ok(!-d $directory, "Firefox::Marionette->new() cleans up the local directory at $directory");
		}
	}

}
ok($profiles_work, "Specified profile names work");
ok($at_least_one_success, "At least one firefox start worked");
eval "no warnings; sub File::Temp::newdir { \$! = POSIX::EACCES(); return; } use warnings;";
ok(!$@, "File::Temp::newdir is redefined to fail:$@");
eval { $class->new(); };
my $output = "$@";
chomp $output;
ok($@->isa('Firefox::Marionette::Exception'), "When File::Temp::newdir is forced to fail, a Firefox::Marionette::Exception is thrown:$output");
my $total_run_time = time - $^T;
if (defined $alarm) {
	my $remaining_time = ($alarm - $total_run_time);
	diag("Total runtime is " . $total_run_time . " seconds (remaining time before alarm of $alarm is $remaining_time)");
} else {
	diag("Total runtime is " . $total_run_time . " seconds");
}
done_testing();
