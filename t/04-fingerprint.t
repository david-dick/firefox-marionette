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
	if (!Test::Daemon::FingerprintJS->fingerprintjs_available()) {
		plan skip_all => "FingerprintJS does not appear to be available";
	}
	if (!Test::Daemon::FingerprintJS->available()) {
		plan skip_all => "yarn does not appear to be available in $ENV{PATH}";
	}
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my $fingerprintjs_listen = '127.0.0.1';
	my $fingerprintjs = Test::Daemon::FingerprintJS->new(listen => $fingerprintjs_listen, debug => $debug);
	ok($fingerprintjs, "Started FingerprintJS Server on $fingerprintjs_listen on port " . $fingerprintjs->port() . ", with pid " . $fingerprintjs->pid());
	eval {
		$fingerprintjs->wait_until_port_open();
	} or do {
		chomp $@;
		diag("Failed to start FingerprintJS daemon:$@");
		last;
	};
	my $firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
			);
	ok($firefox, "Created a firefox object in normal mode");
	my ($major_version, $minor_version, $patch_version) = split /[.]/, $firefox->capabilities()->browser_version();
	TODO: {
		local $TODO = $major_version <= 122 ? 'Older firefoxen may be trackable' : q[];
		ok(!_am_i_trackable_by_fingerprintjs($firefox, $fingerprintjs), "FingerprintJS cannot track this browser");
	}
	ok($firefox->quit() == 0, "Firefox closed successfully");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		trackable => 1,
			);
	ok($firefox, "Created a firefox object in trackable mode");
	ok(_am_i_trackable_by_fingerprintjs($firefox, $fingerprintjs), "FingerprintJS CAN track this browser");
	ok($firefox->quit() == 0, "Firefox closed successfully");
	$firefox = Firefox::Marionette->new(
		debug => $debug,
		visible => $visible,
		trackable => 0,
			);
	ok($firefox, "Created a firefox object in reset trackable mode");
	TODO: {
		local $TODO = $major_version <= 122 ? 'Older firefoxen may be trackable' : q[];
		ok(!_am_i_trackable_by_fingerprintjs($firefox, $fingerprintjs), "FingerprintJS cannot track this browser");
	}
	ok($firefox->quit() == 0, "Firefox closed successfully");
}

sub _am_i_trackable_by_fingerprintjs {
	my ($firefox, $fingerprintjs) = @_;
	ok($firefox->go(q[http://] . $fingerprintjs->address() . q[:] . $fingerprintjs->port()), q[Retrieved fingerprintjs page from http://] . $fingerprintjs->address() . q[:] . $fingerprintjs->port());
	my $original_fingerprint = $firefox->await(sub { $firefox->find_class('giant'); })->text();
	ok($original_fingerprint, "Found fingerprint of $original_fingerprint");
	ok($firefox->restart(), "Restart firefox");
	ok($firefox->go(q[http://] . $fingerprintjs->address() . q[:] . $fingerprintjs->port()), q[Retrieved fingerprintjs page from http://] . $fingerprintjs->address() . q[:] . $fingerprintjs->port());
	my $new_fingerprint = $firefox->await(sub { $firefox->find_class('giant'); })->text();
	ok($new_fingerprint, "Found fingerprint of $new_fingerprint");
	return $new_fingerprint eq $original_fingerprint;
}

done_testing();
