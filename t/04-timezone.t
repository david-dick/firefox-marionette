#! /usr/bin/perl -w

use strict;
use Firefox::Marionette();
use Test::More;
use File::Spec();
use MIME::Base64();
use Socket();
use Config;
use Crypt::URandom();
use Time::Local();
use lib qw(t/);

$SIG{INT} = sub { die "Caught an INT signal"; };
$SIG{TERM} = sub { die "Caught a TERM signal"; };

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
	my $nginx_listen = '127.0.0.1';
	my $htdocs = File::Spec->catdir(Cwd::cwd(), 't', 'data');
	my $nginx = Test::Daemon::Nginx->new(listen => $nginx_listen, htdocs => $htdocs, index => 'timezone.html');
	ok($nginx, "Started nginx Server on " . $nginx->address() . " on port " . $nginx->port() . ", with pid " . $nginx->pid());
	$nginx->wait_until_port_open();
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my %extra_parameters;
	if ($ENV{FIREFOX_BINARY}) {
		$extra_parameters{binary} = $ENV{FIREFOX_BINARY};
	}
	local $ENV{LANG} = 'en-US';
	my %ipgeolocation_responses = (
		'America/New_York' => 'data:application/json,{"ip":"72.229.28.185","continent_code":"NA","continent_name":"North America","country_code2":"US","country_code3":"USA","country_name":"United States","country_name_official":"United States of America","country_capital":"Washington, D.C.","state_prov":"New York","state_code":"US-NY","district":"","city":"New York","zipcode":"10014","latitude":"40.73661","longitude":"-74.00945","is_eu":false,"calling_code":"+1","country_tld":".us","languages":"en-US,es-US,haw,fr","country_flag":"https://ipgeolocation.io/static/flags/us_64.png","geoname_id":"6343019","isp":"Charter Communications Inc","connection_type":"","organization":"Charter Communications Inc","country_emoji":"\uD83C\uDDFA\uD83C\uDDF8","currency":{"code":"USD","name":"US Dollar","symbol":"$"},"time_zone":{"name":"America/New_York","offset":-5,"offset_with_dst":-4,"current_time":"2024-05-24 17:36:16.869-0400","current_time_unix":1716586576.869,"is_dst":true,"dst_savings":1,"dst_exists":true,"dst_start":{"utc_time":"2024-03-10 TIME 07","duration":"+1H","gap":true,"dateTimeAfter":"2024-03-10 TIME 03","dateTimeBefore":"2024-03-10 TIME 02","overlap":false},"dst_end":{"utc_time":"2024-11-03 TIME 06","duration":"-1H","gap":false,"dateTimeAfter":"2024-11-03 TIME 01","dateTimeBefore":"2024-11-03 TIME 02","overlap":true}}}',
		'Australia/Adelaide' => 'data:application/json,{"ip":"58.174.22.52","continent_code":"OC","continent_name":"Oceania","country_code2":"AU","country_code3":"AUS","country_name":"Australia","country_name_official":"Commonwealth of Australia","country_capital":"Canberra","state_prov":"South Australia","state_code":"AU-SA","district":"","city":"Adelaide","zipcode":"5000","latitude":"-34.92585","longitude":"138.59980","is_eu":false,"calling_code":"+61","country_tld":".au","languages":"en-AU","country_flag":"https://ipgeolocation.io/static/flags/au_64.png","geoname_id":"8828296","isp":"Telstra Limited","connection_type":"","organization":"Telstra Corporation","country_emoji":"\uD83C\uDDE6\uD83C\uDDFA","currency":{"code":"AUD","name":"Australian Dollar","symbol":"A$"},"time_zone":{"name":"Australia/Adelaide","offset":9.5,"offset_with_dst":9.5,"current_time":"2024-05-25 07:07:02.397+0930","current_time_unix":1716586622.397,"is_dst":false,"dst_savings":0,"dst_exists":true,"dst_start":{"utc_time":"2024-10-05 TIME 16","duration":"+1H","gap":true,"dateTimeAfter":"2024-10-06 TIME 03","dateTimeBefore":"2024-10-06 TIME 02","overlap":false},"dst_end":{"utc_time":"2025-04-05 TIME 16","duration":"-1H","gap":false,"dateTimeAfter":"2025-04-06 TIME 02","dateTimeBefore":"2025-04-06 TIME 03","overlap":true}}}',
		'Africa/Cairo' => 'data:application/json,{"ip":"197.246.34.1","continent_code":"AF","continent_name":"Africa","country_code2":"EG","country_code3":"EGY","country_name":"Egypt","country_name_official":"Arab Republic of Egypt","country_capital":"Cairo","state_prov":"Cairo Governorate","state_code":"EG-C","district":"","city":"Cairo","zipcode":"4460331","latitude":"30.10007","longitude":"31.33265","is_eu":false,"calling_code":"+20","country_tld":".eg","languages":"ar-EG,en,fr","country_flag":"https://ipgeolocation.io/static/flags/eg_64.png","geoname_id":"8025391","isp":"NOOR","connection_type":"","organization":"NOOR_as20928","country_emoji":"\uD83C\uDDEA\uD83C\uDDEC","currency":{"code":"EGP","name":"Egyptian Pound","symbol":"E£"},"time_zone":{"name":"Africa/Cairo","offset":2,"offset_with_dst":3,"current_time":"2024-05-31 13:54:09.966+0300","current_time_unix":1717152849.966,"is_dst":true,"dst_savings":1,"dst_exists":true,"dst_start":{"utc_time":"2024-04-25 TIME 22","duration":"+1H","gap":true,"dateTimeAfter":"2024-04-26 TIME 01","dateTimeBefore":"2024-04-26 TIME 00","overlap":false},"dst_end":{"utc_time":"2024-10-31 TIME 21","duration":"-1H","gap":false,"dateTimeAfter":"2024-10-31 TIME 23","dateTimeBefore":"2024-11-01 TIME 00","overlap":true}}}',
		'Asia/Tokyo' => 'data:application/json,{"ip":"103.27.184.54","continent_code":"AS","continent_name":"Asia","country_code2":"JP","country_code3":"JPN","country_name":"Japan","country_name_official":"Japan","country_capital":"Tokyo","state_prov":"Tokyo","state_code":"JP-13","district":"","city":"Tokyo","zipcode":"135-0021","latitude":"35.68408","longitude":"139.80885","is_eu":false,"calling_code":"+81","country_tld":".jp","languages":"ja","country_flag":"https://ipgeolocation.io/static/flags/jp_64.png","geoname_id":"6526229","isp":"gbpshk.com","connection_type":"","organization":"Starry Network Limited","country_emoji":"\uD83C\uDDEF\uD83C\uDDF5","currency":{"code":"JPY","name":"Yen","symbol":"¥"},"time_zone":{"name":"Asia/Tokyo","offset":9,"offset_with_dst":9,"current_time":"2024-05-30 05:51:47.239+0900","current_time_unix":1717015907.239,"is_dst":false,"dst_savings":0,"dst_exists":false,"dst_start":"","dst_end":""}}',
				);
	my @ids = qw(
			locale
			unixTime
			toString
			toLocaleString
			getDate
			getDay
			getMonth
			getFullYear
			getHours
			getMinutes
			getSeconds
			Collator
			DisplayNames
			DurationFormat
			ListFormat
			PluralRules
			RelativeTimeFormat
			Segmenter
		);
	my $locale_diag;
	my $now = time;
	foreach my $timezone (sort { $a cmp $b } keys %ipgeolocation_responses) {
		ok($timezone, "Using timezone '$timezone'");
		my %correct_answers;
		{
			local $ENV{TZ} = $timezone;
			my $firefox = Firefox::Marionette->new(
									%extra_parameters,
									debug => $debug,
									visible => $visible,
								);
			ok($firefox, "Created a normal firefox object");
			foreach my $time (
						Time::Local::timegm(1,0,0,1,0,2000),
						Time::Local::timegm(59,59,23,31,11,2010),
						Time::Local::timegm(5,5,5,5,5,2005),
					) {
				ok($time, "Current time in $timezone is " . localtime $time);
				my $url = 'http://' . $nginx->address() . q[:] . $nginx->port() . '#' . $time;
				ok($firefox->go('about:blank'), "reset url to about:blank");
				ok($firefox->go($url), "go to $url with TZ set to $timezone");
				foreach my $id (@ids) {
					$correct_answers{$time}{$id} = $firefox->find_id($id)->text();
					if (($id eq 'locale') && (!$locale_diag)) {
						diag("Using locale of '$correct_answers{$time}{$id}'");
						$locale_diag = 1;
					}
					ok(defined $correct_answers{$time}{$id}, "\$firefox->find_id('$id')->text() is '$correct_answers{$time}{$id}' in $timezone");
				}
			}
			$firefox->quit();
		}
		my $firefox = Firefox::Marionette->new(
								%extra_parameters,
								debug => $debug,
								visible => $visible,
								geo => $ipgeolocation_responses{$timezone},
							);
		ok($firefox, "Created a normal firefox object");
		foreach my $time (sort { $a <=> $b } keys %correct_answers) {
			ok($time, "Current time in $timezone is " . localtime $time);
			my $url = 'http://' . $nginx->address() . q[:] . $nginx->port() . '#' . $time;
			ok($firefox->go('about:blank'), "reset url to about:blank");
			ok($firefox->go($url), "go to $url with geo timezone set to $timezone");
			foreach my $id (@ids) {
				my $actual_answer =  $firefox->find_id($id)->text();
				ok($correct_answers{$time}{$id} eq $actual_answer, "\$firefox->find_id('$id')->text() returned '$correct_answers{$time}{$id}':'$actual_answer'");
				$actual_answer =  $firefox->find_id('iframe_' . $id)->text();
				ok($correct_answers{$time}{$id} eq $actual_answer, "\$firefox->find_id('iframe_$id')->text() returned '$correct_answers{$time}{$id}':'$actual_answer'");
			}
		}
		$timezone = 'Australia/Melbourne';
		ok($firefox->tz($timezone), "\$firefox->tz(\"$timezone\") is called to override the timezone");
		my $url = 'http://' . $nginx->address() . q[:] . $nginx->port() . '#' . $now;
		ok($firefox->go('about:blank'), "reset url to about:blank");
		ok($firefox->go($url), "go to $url with timezone set to $timezone");
		my $id = 'toString';
		my $override_answer =  $firefox->find_id($id)->text();
		ok($override_answer =~ /GMT[+]1[10]00/smx, "\$firefox->find_id('$id')->text() returned an answer matching Melbourne:'$override_answer'");
		ok($firefox->quit() == 0, "\$firefox->quit() succeeded");
	}
	ok($nginx->stop() == 0, "Stopped nginx on " . $nginx->address() . q[:] . $nginx->port());
}

done_testing();
