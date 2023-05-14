#! /usr/bin/perl -w

use strict;
use lib qw(t/);
use syscall_tests (qw(fork));

*CORE::GLOBAL::fork = sub { if (syscall_tests::allow()) { CORE::fork; } else { $! = POSIX::ENOMEM(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::ENOMEM());

TODO: {
	local $syscall_tests::TODO = $^O eq 'MSWin32' ? "There are no fork calls in $^O": q[];
	syscall_tests::visible(POSIX::ENOENT());
}

no warnings;
*CORE::GLOBAL::fork = sub { return CORE::fork; };
use warnings;

syscall_tests::finalise();
