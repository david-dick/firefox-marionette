#! /usr/bin/perl -w

use strict;
use Firefox::Marionette();
use Test::More;
use File::Spec();
use lib qw(t/);

$SIG{INT} = sub { die "Caught an INT signal"; };
$SIG{TERM} = sub { die "Caught a TERM signal"; };

SKIP: {
	if (!$ENV{RELEASE_TESTING}) {
                plan skip_all => "Author tests not required for installation";
	}
	if ($^O eq 'MSWin32') {
		plan skip_all => "Cannot test in a $^O environment";
	}
	require test_daemons;
	if (!Test::Daemon::Botd->botd_available()) {
		plan skip_all => "BotD does not appear to be available";
	}
	if (!Test::Daemon::Botd->available()) {
		plan skip_all => "yarn does not appear to be available in $ENV{PATH}";
	}
	my $override_address = $^O eq 'linux' ? undef : '127.0.0.1';
	my $botd_listen = $override_address || '127.0.0.2';
	my $botd = Test::Daemon::Botd->new(listen => $botd_listen);
	ok($botd, "Started botd Server on $botd_listen on port " . $botd->port() . ", with pid " . $botd->pid());
	$botd->wait_until_port_open();
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my $firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
			);
	ok($firefox, "Created a firefox object in normal mode");
	ok(_am_i_a_bot($firefox, $botd), "BotD did detect a bot");
	my %correct_values = _get_property_descriptors($firefox);
	foreach my $property (sort { $a cmp $b } keys %correct_values) {
		foreach my $descriptor (sort { $a cmp $b } keys %{$correct_values{$property}}) {
			ok(1, "navigator.$property ($descriptor) = $correct_values{$property}{$descriptor}");
		}
	}
	ok($firefox->quit() == 0, "Firefox closed successfully");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		stealth => 1,
			);
	ok($firefox, "Created a firefox object in stealth mode");
	ok(!_am_i_a_bot($firefox, $botd), "BotD did NOT detect a bot");
	my %actual_values = _get_property_descriptors($firefox);
	foreach my $property (sort { $a cmp $b } keys %correct_values) {
		foreach my $descriptor (sort { $a cmp $b } keys %{$correct_values{$property}}) {
			ok($correct_values{$property}{$descriptor} eq $actual_values{$property}{$descriptor}, "navigator.$property ($descriptor) = $correct_values{$property}{$descriptor}:$actual_values{$property}{$descriptor}");
		}
	}
	my $json = JSON::decode_json($firefox->find_id('debug-data')->text());
	ok($json->{browserKind} eq 'firefox', "BotD reports browserKind of 'firefox':$json->{browserKind}");
	ok($json->{browserEngineKind} eq 'gecko', "BotD reports browserEngineKind of 'gecko':$json->{browserEngineKind}");
	ok($firefox->quit() == 0, "Firefox closed successfully");
	foreach my $agent (
				q[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36],
				q[Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15],
			) {
		$firefox = Firefox::Marionette->new(
			debug => $debug,
			visible => $visible,
			stealth => 1,
				);
		ok($firefox, "Created a firefox object in stealth mode");
		ok($firefox->agent($agent), "Setting user agent to '$agent'");
		ok(!_am_i_a_bot($firefox, $botd), "BotD did NOT detect a bot");
		my %actual_values = _get_property_descriptors($firefox);
		foreach my $property (sort { $a cmp $b } keys %correct_values) {
			foreach my $descriptor (sort { $a cmp $b } keys %{$correct_values{$property}}) {
				if (defined $actual_values{$property}{$descriptor}) {
					my $correct_value = $correct_values{$property}{$descriptor};
					if ($agent =~ /Chrome/smx) {
						$correct_value = qq[function $property() { [native code] }];
					} else {
						$correct_value = qq[function $property() {\\n    [native code]\\n}];
					}
					ok($actual_values{$property}{$descriptor} eq $correct_value, "navigator.$property ($descriptor) = $correct_value:$actual_values{$property}{$descriptor}");
				}
			}
		}
		$json = JSON::decode_json($firefox->find_id('debug-data')->text());
		if ($agent =~ /Chrome/smx) {
			ok($json->{browserKind} eq 'chrome', "BotD reports browserKind of 'chrome':$json->{browserKind}");
			ok($json->{browserEngineKind} eq 'chromium', "BotD reports browserEngineKind of 'chromium':$json->{browserEngineKind}");
		} else {
			ok($json->{browserKind} eq 'safari', "BotD reports browserKind of 'safari':$json->{browserKind}");
			ok($json->{browserEngineKind} eq 'webkit', "BotD reports browserEngineKind of 'webkit':$json->{browserEngineKind}");
		}
		ok($firefox->quit() == 0, "Firefox closed successfully");
	}
	ok($botd->stop() == 0, "Stopped botd on $botd_listen:" . $botd->port());
}

sub _am_i_a_bot {
	my ($firefox, $botd) = @_;
	my $bot_not_detected_string = 'You are not a bot.';
	ok($firefox->go(q[http://] . $botd->address() . q[:] . $botd->port()), q[Retrieved botd page from http://] . $botd->address() . q[:] . $botd->port());
	my $result = $firefox->find_id('result-text')->text();
	return $result ne $bot_not_detected_string;
}

sub _get_property_descriptors {
	my ($firefox) = @_;
	my %values;
	foreach my $property (qw(vendor vendorSub productSub oscpu)) {
		foreach my $descriptor (qw(get)) {
			if (defined $firefox->script("return Object.getOwnPropertyDescriptor(window.Navigator.prototype, '$property')")) {
				$values{$property}{$descriptor} = $firefox->script("return Object.getOwnPropertyDescriptor(window.Navigator.prototype, '$property').$descriptor.toString()");
				$values{$property}{$descriptor} =~ s/\n/\\n/smxg;
			}
		}
	}
	return %values;
}

done_testing();
