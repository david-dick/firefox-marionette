#! /usr/bin/perl -w

use strict;
use lib qw(t/);
use syscall_tests (qw(sysopen));

*CORE::GLOBAL::sysopen = sub { my $handle = CORE::sysopen $_[0], $_[1], $_[2]; if (($handle) && (syscall_tests::allow())) { return $handle } else { $! = POSIX::EACCES(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::EACCES());
syscall_tests::visible(POSIX::EACCES());

no warnings;
*CORE::GLOBAL::sysopen = sub { return CORE::sysopen $_[0], $_[1], $_[2]; };
use warnings;

syscall_tests::finalise();
