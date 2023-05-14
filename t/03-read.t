#! /usr/bin/perl -w

use strict;
use JSON();
BEGIN {
	if (($^O eq 'cygwin') || ($^O eq 'darwin') || ($^O eq 'MSWin32')) {
	} else {
		require Crypt::URandom;
		require FileHandle;
	}
}
use lib qw(t/);
use syscall_tests (qw(read));

*CORE::GLOBAL::read = sub { if (syscall_tests::allow()) { CORE::read $_[0], $_[1], $_[2]; } else { $! = POSIX::EACCES(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::EACCES());
syscall_tests::visible(POSIX::EACCES());

no warnings;
*CORE::GLOBAL::read = sub { return CORE::read $_[0], $_[1], $_[2]; };
use warnings;

syscall_tests::finalise();
