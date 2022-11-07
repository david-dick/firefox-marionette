#! /usr/bin/perl -wT

use strict;
use Firefox::Marionette();
use Test::More;

$ENV{PATH} = '/bin:/usr/bin:/sbin:/bin:/usr/local/bin';
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

my %parameters;
if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} =~ /^(.*)$/smx)) {
	$parameters{host} = $1;
	diag("Overriding host to '$parameters{host}'");
	if (($ENV{FIREFOX_VIA}) && ($ENV{FIREFOX_VIA} =~ /^(.*)$/smx)) {
		$parameters{via} = $1;
	}
	if (($ENV{FIREFOX_USER}) && ($ENV{FIREFOX_USER} =~ /^(.*)$/smx)) {
		$parameters{user} = $1;
	} elsif (($ENV{FIREFOX_HOST} eq 'localhost') && (!$ENV{FIREFOX_PORT})) {
		$parameters{user} = 'firefox';
	}
	if (($ENV{FIREFOX_PORT}) && ($ENV{FIREFOX_PORT} =~ /^(\d+)$/smx)) {
		$parameters{port} = $1;
	}
}
if ($ENV{FIREFOX_DEBUG}) {
	$parameters{debug} = $ENV{FIREFOX_DEBUG};
}
my $firefox = Firefox::Marionette->new(%parameters);
ok($firefox, "Firefox launched okay under taint");
ok($firefox->quit() == 0, "Firefox exited okay under taint");

done_testing();
