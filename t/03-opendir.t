#! /usr/bin/perl -w

use strict;
use Archive::Zip();
use XML::Parser();
use lib qw(t/);
use syscall_tests (qw(opendir));

*CORE::GLOBAL::opendir = sub { if (syscall_tests::allow()) { CORE::opendir $_[0], $_[1]; } else { $! = POSIX::EACCES(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::EACCES());
syscall_tests::visible(POSIX::EACCES());

no warnings;
*CORE::GLOBAL::opendir = sub { return CORE::opendir $_[0], $_[1]; };
use warnings;

syscall_tests::finalise();
