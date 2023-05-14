#! /usr/bin/perl -w

use strict;
use lib qw(t/);
use syscall_tests (qw(mkdir));

*CORE::GLOBAL::mkdir = sub { if (syscall_tests::allow()) { CORE::mkdir $_[0]; } else { $! = POSIX::EACCES(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::EACCES());
syscall_tests::visible(POSIX::EACCES());

no warnings;
*CORE::GLOBAL::mkdir = sub { return CORE::mkdir $_[0]; };
use warnings;

syscall_tests::finalise();
