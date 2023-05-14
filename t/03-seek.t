#! /usr/bin/perl -w

use strict;
use lib qw(t/);
use syscall_tests (qw(seek));

*CORE::GLOBAL::seek = sub { if (syscall_tests::allow()) { return CORE::seek $_[0], $_[1], $_[2]; } else { $! = POSIX::ESPIPE(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::ESPIPE());
syscall_tests::visible(POSIX::ESPIPE());

no warnings;
*CORE::GLOBAL::seek = sub { return CORE::seek $_[0], $_[1], $_[2]; };
use warnings;

syscall_tests::finalise();
