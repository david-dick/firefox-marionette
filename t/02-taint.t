#! /usr/bin/perl -wT

use strict;
use Firefox::Marionette();
use Test::More;

$ENV{PATH} = '/bin:/usr/bin:/sbin:/bin';
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

my $firefox = Firefox::Marionette->new();
ok($firefox, "Firefox launched okay under taint");
ok($firefox->quit() == 0, "Firefox exited okay under taint");

done_testing();
