#! /usr/bin/perl -w

use strict;
use Archive::Zip();
use lib qw(t/);
use syscall_tests (qw(stat));

*CORE::GLOBAL::stat = sub { if (syscall_tests::allow()) { CORE::stat $_[0]; } else { $! = POSIX::ENOENT(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::ENOENT());

TODO: {
	local $syscall_tests::TODO = (($^O eq 'darwin') or ($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? "There are no stat calls when $^O firefox starts": q[];
	syscall_tests::visible(POSIX::ENOENT());
}

no warnings;
*CORE::GLOBAL::stat = sub { return CORE::stat $_[0]; };
use warnings;

syscall_tests::finalise();
