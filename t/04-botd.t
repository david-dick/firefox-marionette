#! /usr/bin/perl -wT

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
	if (!Test::Daemon::Botd->botd_available()) {
		plan skip_all => "BotD does not appear to be available";
	}
	if (!Test::Daemon::Botd->available()) {
		plan skip_all => "yarn does not appear to be available";
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
	ok($firefox->quit() == 0, "Firefox closed successfully");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		stealth => 1,
			);
	ok($firefox, "Created a firefox object in stealth mode");
	ok(!_am_i_a_bot($firefox, $botd), "BotD did NOT detect a bot");
	ok($firefox->quit() == 0, "Firefox closed successfully");
	foreach my $agent (
				q[Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36]
			) {
		$firefox = Firefox::Marionette->new(
			debug => $debug,
			visible => $visible,
			stealth => 1,
				);
		ok($firefox, "Created a firefox object in stealth mode");
		ok($firefox->agent($agent), "Setting user agent to '$agent'");
		ok(!_am_i_a_bot($firefox, $botd), "BotD did NOT detect a bot");
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

done_testing();
