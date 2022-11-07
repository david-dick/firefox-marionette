#! /usr/bin/perl -wT

use strict;
use Firefox::Marionette();
use Test::More;
use File::Spec();

my $dev_null = File::Spec->devnull();
my $run_taint_checks = 1;
if ($^O eq 'Win32') {
	diag("Checking taint under $^O");
} else {
	delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
	if (defined $ENV{PATH}) {
		$ENV{PATH} = '/usr/bin:/bin:/usr/local/bin';	
		if (my $pid = fork) {
			waitpid $pid, 0;
			if ($? == 0) {
				diag("Running taint checks with PATH set to $ENV{PATH}");
			} else {
				diag("Unable to exec firefox with PATH set to $ENV{PATH}.  No taint checks to be run");
				$run_taint_checks = 0;
			}
		} elsif (defined $pid) {
			eval {
				open STDOUT, q[>], $dev_null or die "Failed to redirect STDOUT to $dev_null:$!";
				open STDERR, q[>], $dev_null or die "Failed to redirect STDERR to $dev_null:$!";
				exec { 'firefox' } 'firefox', '--version' or die "Failed to exec 'firefox':$!";
			} or do {
				warn $@;
			};
			exit 1;
		}
	}
}

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
SKIP: {
	if (!$run_taint_checks) {
		skip("Unable to run firefox with PATH set to $ENV{PATH}", 2);
	}
	my $firefox = Firefox::Marionette->new(%parameters);
	ok($firefox, "Firefox launched okay under taint");
	ok($firefox->quit() == 0, "Firefox exited okay under taint");
}

done_testing();
