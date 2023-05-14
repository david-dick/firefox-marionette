#! /usr/bin/perl -w

use strict;
use Archive::Zip();
use XML::Parser();
use lib qw(t/);
use syscall_tests (qw(closedir));

*CORE::GLOBAL::closedir = sub { if (syscall_tests::allow()) { CORE::closedir $_[0]; } else { $! = POSIX::EBADF(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::EBADF());
syscall_tests::visible(POSIX::EBADF());

no warnings;
*CORE::GLOBAL::closedir = sub { return CORE::closedir $_[0]; };
use warnings;

syscall_tests::finalise();
