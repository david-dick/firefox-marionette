#! /usr/bin/perl -w

use strict;
use JSON();
use IPC::Open3();
use Archive::Zip();
use XML::Parser();
use lib qw(t/);
use syscall_tests (qw(close));

*CORE::GLOBAL::close = sub { if (syscall_tests::allow()) { CORE::close $_[0]; } else { $! = POSIX::EIO(); return } };

require Firefox::Marionette;

syscall_tests::run(POSIX::EIO());
syscall_tests::visible(POSIX::EIO());

no warnings;
*CORE::GLOBAL::close = sub { return CORE::close $_[0]; };
use warnings;

syscall_tests::finalise();
