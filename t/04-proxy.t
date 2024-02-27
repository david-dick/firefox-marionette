#! /usr/bin/perl -wT

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
	my $socks_listen = $override_address || '127.0.0.6';
	my $nginx_username = MIME::Base64::encode_base64( Crypt::URandom::urandom( 50 ), q[] );
	my $nginx_password = MIME::Base64::encode_base64( Crypt::URandom::urandom( 100 ), q[] );
	my $nginx_realm = "Nginx Server for Firefox::Marionette $0";
	my $nginx = Test::Daemon::Nginx->new(listen => $nginx_listen, key_size => $default_rsa_key_size, ca => $ca, $ENV{FIREFOX_NO_WEB_AUTH} ? () : ( username => $nginx_username, password => $nginx_password, realm => $nginx_realm));
	ok($nginx, "Started nginx Server on $nginx_listen on port " . $nginx->port() . ", with pid " . $nginx->pid());
	$nginx->wait_until_port_open();
	my $squid_username = MIME::Base64::encode_base64( Crypt::URandom::urandom( 50 ), q[] );
	my $squid_password = MIME::Base64::encode_base64( Crypt::URandom::urandom( 100 ), q[] );
	my $squid_realm = "Squid Proxy for Firefox::Marionette $0";
	my $squid = Test::Daemon::Squid->new(listen => $squid_listen, key_size => $default_rsa_key_size, ca => $ca, allow_ssl_port => $nginx->port(), $ENV{FIREFOX_NO_PROXY_AUTH} ? () : (username => $squid_username, password => $squid_password, realm => $squid_realm));
	ok($squid, "Started squid Server on $squid_listen on port " . $squid->port() . ", with pid " . $squid->pid());
	$squid->wait_until_port_open();
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
			next AUTH_LOOP;
		};
		my $strip = $firefox->strip();
		TODO: {
			local $TODO = $ENV{FIREFOX_NO_WEB_AUTH} ? q[] : "Firefox can have race conditions for basic web auth";
			ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and web proxies:$strip:");
			if ($strip ne $nginx->content()) {
				next AUTH_LOOP;
			}
		}
		ok($firefox->quit() == 0, "Firefox closed successfully");
	}
	ok($nginx->stop() == 0, "Stopped nginx on $nginx_listen:" . $nginx->port());
	ok($squid->stop() == 0, "Stopped HTTPS proxy on $squid_listen:" . $squid->port());
	$nginx = Test::Daemon::Nginx->new(listen => $nginx_listen);
	ok($nginx, "Started nginx Server on $nginx_listen on port " . $nginx->port() . ", with pid " . $nginx->pid());
	$nginx->wait_until_port_open();
	my $squid1 = Test::Daemon::Squid->new(listen => $squid_listen, allow_port => $nginx->port());
	ok($squid1, "Started squid Server on $squid_listen on port " . $squid1->port() . ", with pid " . $squid1->pid());
	$squid1->wait_until_port_open();
	my $squid2 = Test::Daemon::Squid->new(listen => $squid_listen, key_size => $default_rsa_key_size, ca => $ca, allow_port => $nginx->port());
	ok($squid2, "Started squid Server on $squid_listen on port " . $squid2->port() . ", with pid " . $squid2->pid());
	$squid2->wait_until_port_open();
	{
		local $ENV{all_proxy} = 'https://' . $squid_listen . ':' . $squid2->port();
		my $firefox = Firefox::Marionette->new(
			debug => $debug,
			visible => $visible,
			profile => $profile,
			trust => $ca->cert(),
					);
		ok($firefox, "Created a firefox object going through ssh and the all_proxy environment variable of (https://$squid_listen:" . $squid2->port() . ")");
		ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with all_proxy environment variable");
		my $strip = $firefox->strip();
		ok($strip eq $nginx->content(), "Successfully retrieved web page through all_proxy environment variable");
		ok($squid2->stop() == 0, "Stopped HTTPS proxy on $squid_listen:" . $squid2->port());
		ok($firefox->go("about:blank"), "Reset current webpage to about:blank");
		eval {
			$firefox->go("http://$nginx_listen:" . $nginx->port());
		};
		chomp $@;
		ok($@, "Failed to load website when proxy specified by all_proxy environment variable is down:$@");
		ok($firefox->go("about:blank"), "Reset current webpage to about:blank");
		ok($squid2->start(), "Started HTTPS proxy on $squid_listen:" . $squid2->port());
		$squid2->wait_until_port_open();
		eval {
			$firefox->go("http://$nginx_listen:" . $nginx->port());
		};
		chomp $@;
		if ($@) {
			diag("Needed another page load to retry the restarted proxy");
		}
		ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with all_proxy environment variable");
		$strip = $firefox->strip();
		ok($strip eq $nginx->content(), "Successfully retrieved web page through all_proxy environment variable");
	}
	my $firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		trust => $ca->cert(),
		proxy => [ "http://$squid_listen:" . $squid1->port(), "https://$squid_listen:" . $squid2->port ],
				);
	ok($firefox, "Created a firefox object going through ssh and redundant ($squid_listen:" . $squid1->port() . " then $squid_listen:" . $squid2->port() . ") web proxies");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with redundant web proxies");
	my $strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and redundant web proxies:$strip:");
	ok($firefox->go('about:blank'), 'Reset webpage to about:blank');
	ok($squid1->stop() == 0, "Stopped primary HTTP proxy on $squid_listen:" . $squid1->port());
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with backup HTTPS proxy");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and backup HTTPS proxies:$strip:");
	ok($squid1->start(), "Started primary HTTP proxy on $squid_listen:" . $squid1->port());
	$squid1->wait_until_port_open();
	ok($squid2->stop() == 0, "Stopped backup HTTPS proxy on $squid_listen:" . $squid2->port());
	eval {
		$firefox->go("http://$nginx_listen:" . $nginx->port());
	};
	chomp $@;
	if ($@) {
		ok($@ =~ /proxyConnectFailure/, "Firefox threw an exception b/c of proxy failure:$@");
		ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with primary HTTP proxy");
		$strip = $firefox->strip();
		ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and primary HTTP proxy:$strip:");
	} else {
		$strip = $firefox->strip();
		diag("No exception thrown when proxy stopped");
		ok($strip eq $nginx->content(), "Successfully retrieved web page without throwing an exception through ssh and primary HTTP proxy:$strip:");
	}
	ok($firefox->quit() == 0, "Firefox closed successfully");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		proxy => "http://$squid_listen:" . $squid1->port(),
				);
	ok($firefox, "Created a firefox object going through ssh and http ($squid_listen:" . $squid1->port() . ") proxy");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with HTTP proxy");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and HTTP proxy:$strip:");
	ok($squid1->stop() == 0, "Stopped HTTP proxy on $squid_listen:" . $squid->port());
	my $socks = Test::Daemon::Socks->new(listen => $socks_listen, debug => 1);
	ok($socks, "Started SOCKS Server on $socks_listen on port " . $socks->port() . ", with pid " . $socks->pid());
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		proxy => Firefox::Marionette::Proxy->new( socks => "$socks_listen:" . $socks->port() ),
				);
	ok($firefox, "Created a firefox object going through ssh and SOCKS ($socks_listen:" . $socks->port() . ") proxy");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with SOCKS proxy");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and SOCKS proxy:$strip:");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		proxy => Firefox::Marionette::Proxy->new( socks => "$socks_listen:" . $socks->port(), socks_version => 5 ),
				);
	ok($firefox, "Created a firefox object going through ssh and SOCKS ($socks_listen:" . $socks->port() . ") proxy with version specified");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with SOCKS proxy (v5)");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and SOCKS proxy (v5):$strip:");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		proxy => "socks://$socks_listen:" . $socks->port(),
				);
	ok($firefox, "Created a firefox object going through ssh and SOCKS URI (socks://$socks_listen:" . $socks->port() . ") proxy ");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with SOCKS proxy (v5)");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and SOCKS proxy (v5):$strip:");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		proxy => "socks4://$socks_listen:" . $socks->port(),
				);
	ok($firefox, "Created a firefox object going through ssh and SOCKS URI (socks4://$socks_listen:" . $socks->port() . ") proxy ");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with SOCKS proxy (v4)");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and SOCKS proxy (v4):$strip:");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		profile => $profile,
		host  => "$sshd_listen:22",
		via   => "$jumpd_listen:22",
		proxy => "socks5://$socks_listen:" . $socks->port(),
				);
	ok($firefox, "Created a firefox object going through ssh and SOCKS URI (socks5://$socks_listen:" . $socks->port() . ") proxy ");
	ok($firefox->go("http://$nginx_listen:" . $nginx->port()), "Retrieved webpage with SOCKS proxy (v5)");
	$strip = $firefox->strip();
	ok($strip eq $nginx->content(), "Successfully retrieved web page through ssh and SOCKS proxy (v5):$strip:");
	ok($nginx->stop() == 0, "Stopped nginx on $nginx_listen:" . $nginx->port());
	ok($socks->stop() == 0, "Stopped SOCKS proxy on $socks_listen:" . $socks->port());
}

done_testing();
