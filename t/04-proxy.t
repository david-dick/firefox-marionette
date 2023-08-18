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
	my $nginx_username = MIME::Base64::encode_base64( Crypt::URandom::urandom( 50 ), q[] );
	my $nginx_password = MIME::Base64::encode_base64( Crypt::URandom::urandom( 100 ), q[] );
	my $nginx_realm = "Nginx Server for Firefox::Marionette $0";
	my $nginx = Test::Daemon::Nginx->new(listen => $nginx_listen, key_size => $default_rsa_key_size, ca => $ca, $ENV{FIREFOX_NO_WEB_AUTH} ? () : ( username => $nginx_username, password => $nginx_password, realm => $nginx_realm));
	ok($nginx, "Started nginx Server on $nginx_listen on port " . $nginx->port() . ", with pid " . $nginx->pid());
	my $squid_username = MIME::Base64::encode_base64( Crypt::URandom::urandom( 50 ), q[] );
	my $squid_password = MIME::Base64::encode_base64( Crypt::URandom::urandom( 100 ), q[] );
	my $squid_realm = "Squid Proxy for Firefox::Marionette $0";
	my $squid = Test::Daemon::Squid->new(listen => $squid_listen, key_size => $default_rsa_key_size, ca => $ca, allow_ssl_port => $nginx->port(), $ENV{FIREFOX_NO_PROXY_AUTH} ? () : (username => $squid_username, password => $squid_password, realm => $squid_realm));
	ok($squid, "Started squid Server on $squid_listen on port " . $squid->port() . ", with pid " . $squid->pid());
	my $profile = Firefox::Marionette::Profile->new();
	$profile->set_value( 'network.proxy.allow_hijacking_localhost', 'true', 0 );
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my $loop_max = $ENV{FIREFOX_MAX_LOOP} || 1;
	AUTH_LOOP: foreach my $loop_count (1 .. $loop_max) {
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
		if (!$ENV{FIREFOX_NO_PROXY_AUTH}) {
			ok($firefox->add_login(host => "moz-proxy://$squid_listen:" . $squid->port(), user => $squid_username, password => $squid_password, realm => $squid_realm), "Added proxy credentials");
		}
		if (!$ENV{FIREFOX_NO_WEB_AUTH}) {
			ok($firefox->add_login(host => "https://$nginx_listen:" . $nginx->port(), user => $nginx_username, password => $nginx_password, realm => $nginx_realm), "Added web server credentials");
		}
		eval {
			if ($ENV{FIREFOX_NO_WEB_AUTH}) {
				ok($firefox->go("https://$nginx_listen:" . $nginx->port()), "Retrieved webpage (no web server auth)");
			} else {
				ok($firefox->go("https://$nginx_listen:" . $nginx->port())->accept_alert()->await(sub { $firefox->loaded() }), "Retrieved webpage");
			}
		} or do {
			chomp $@;
			diag("Did not load webpage:$@");
			redo AUTH_LOOP;
		};
		my $strip = $firefox->strip();
		TODO: {
			local $TODO = $ENV{FIREFOX_NO_WEB_AUTH} ? q[] : "Firefox can have race conditions for basic web auth";
			ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and web proxies:$strip:");
			if ($strip ne $nginx->content()) {
				redo AUTH_LOOP;
			}
		}
		ok($firefox->quit() == 0, "Firefox closed successfully");
	}
	$nginx->quit();
	$squid->quit();
}

done_testing();
