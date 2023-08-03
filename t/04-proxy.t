#! /usr/bin/perl -wT

use strict;
use Firefox::Marionette();
use Test::More;
use File::Spec();
use Socket();
use Config;
use Crypt::URandom();
use lib qw(t/);

$SIG{INT} = sub { die "Caught an INT signal"; };
$SIG{TERM} = sub { die "Caught a TERM signal"; };

SKIP: {
	if (!$ENV{RELEASE_TESTING}) {
		plan skip_all => 'RELEASE_TESTING only';
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
	if (!Test::CA->available()) {
		plan skip_all => "openssl does not appear to be available";
	}
	my $default_rsa_key_size = 4096;
	if (!Test::Daemon::Nginx->available()) {
		plan skip_all => "nginx does not appear to be available";
	}
	if (!Test::Daemon::Squid->available()) {
		plan skip_all => "squid does not appear to be available";
	}
	my $override_address = $^O eq 'linux' ? undef : '127.0.0.1';
	my $jumpd_listen = 'localhost';
	if (!Test::Daemon::SSH->connect_and_exit($jumpd_listen)) {
		plan skip_all => "Cannot login to $jumpd_listen with ssh";
	}
	my $sshd_listen = $override_address || '127.0.0.3';
	if (!Test::Daemon::SSH->connect_and_exit($sshd_listen)) {
		plan skip_all => "Cannot login to $sshd_listen with ssh";
	}
	my $ca = Test::CA->new($default_rsa_key_size);
	my $squid_listen = $override_address || '127.0.0.4';
	my $nginx_listen = $override_address || '127.0.0.5';
	my $nginx = Test::Daemon::Nginx->new(listen => $nginx_listen, key_size => $default_rsa_key_size, ca => $ca);
	ok($nginx, "Started nginx Server on $nginx_listen on port " . $nginx->port() . ", with pid " . $nginx->pid());
	my $squid = Test::Daemon::Squid->new(listen => $squid_listen, key_size => $default_rsa_key_size, ca => $ca, allow_ssl_port => $nginx->port());
	ok($squid, "Started squid Server on $squid_listen on port " . $squid->port() . ", with pid " . $squid->pid());
	my $profile = Firefox::Marionette::Profile->new();
        $profile->set_value( 'network.proxy.allow_hijacking_localhost', 'true', 0 );
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my $firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		trust => $ca->cert(),
		proxy => "https://$squid_listen:" . $squid->port()
				);
	ok($firefox, "Created a firefox object going through ssh and web proxies");
	ok($firefox->go("https://$nginx_listen:" . $nginx->port()), "Retrieved webpage");
	ok($firefox->strip() eq $nginx->content(), "Successfully retrieved web page through ssh and web proxies");
	ok($firefox->quit() == 0, "Firefox closed successfully");
	$nginx->quit();
	$squid->quit();
}

done_testing();
