package syscall_tests;

use strict;
use warnings;
use Test::More;
use File::Spec();
use Fcntl();
use File::Path();
use Cwd();
BEGIN {
	if ($^O eq 'MSWin32') {
		require Win32;
		require Win32::Process;
		require Win32API::Registry;
	}
}

my $base_directory;
my $syscall_count = 0;
my $syscall_error_at_count = 0;
my $function;
my %parameters;

my @CHARS = (qw/ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
                 a b c d e f g h i j k l m n o p q r s t u v w x y z
                 0 1 2 3 4 5 6 7 8 9 _
               /);

sub import {
	my $class = shift @_;
	$function = shift;

	unless ($ENV{RELEASE_TESTING}) {
		plan( skip_all => "Author tests not required for installation" );
	}
	if ($^O eq 'MSWin32') {
		plan( skip_all => "Syscall tests not reliable for $^O");
	}

	$base_directory = File::Spec->catdir(File::Spec->tmpdir(), 'firefox_marionette_test_suite_syscall_' . 'X' x 11);
	my $end = ( $] >= 5.006 ? "\\z" : "\\Z" );
	$base_directory =~ s/X(?=X*$end)/$CHARS[ int( rand( @CHARS ) ) ]/gesmx;
	mkdir $base_directory, Fcntl::S_IRWXU() or die "Failed to create temporary directory:$!";
	$ENV{TMPDIR} = $base_directory;

	return;
}

sub allow {
	my ($package, $file, $line) = caller;
	if ((defined $syscall_error_at_count) && ($syscall_count == $syscall_error_at_count)) {
		$syscall_count += 1;
		return 0;
	} else {
		$syscall_count += 1;
		return 1;
	}
}

sub run {
	my ($class, $expected_error_as_posix) = @_;
	my $cwd = Cwd::cwd();
	%parameters = (
			binary => File::Spec->catfile($cwd, 't', 'stub.pl'),
			har => 1,
			stealth => 1,
		);
	my $success = 0;
	while(!$success) {
		$syscall_count = 0;
		eval {
			my $firefox = Firefox::Marionette->new(%parameters);
			$firefox->pdf();
			$firefox->selfie();
			$firefox->import_bookmarks(File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_empty.html)));
		        $firefox->agent(version => 100);
			my $final = $syscall_error_at_count;
			$syscall_error_at_count = undef;
			ok($syscall_count >= 0 && $firefox->quit() == 0, "Firefox exited okay after $final successful $function calls");
			$success = 1;
		} or do {
			chomp $@;
			my $actual_error_message = $@;
			my $expected_error_message = quotemeta POSIX::strerror($expected_error_as_posix);
			ok($actual_error_message =~ /(?:$expected_error_message|[ ]exited[ ]with[ ]a[ ][1])/smx, "Firefox failed with $function count set to $syscall_error_at_count:" . $actual_error_message);
			$syscall_error_at_count += 1;
		};
	}
	my $firefox = Firefox::Marionette->new(%parameters);
	ok($firefox->quit() == 0, "Firefox exited okay when $function is reset");
}

sub visible {
	my ($class, $expected_error_as_posix) = @_;
	$syscall_error_at_count = 0;
	delete $ENV{DISPLAY};
	$parameters{visible} = 1;
	my $success = 0;
	while(!$success) {
		$syscall_count = 0;
		eval {
			my $firefox = Firefox::Marionette->new(%parameters);
			$firefox->pdf();
			$firefox->selfie();
			$firefox->import_bookmarks(File::Spec->catfile(Cwd::cwd(), qw(t data bookmarks_empty.html)));
			my $final = $syscall_error_at_count;
			$syscall_error_at_count = undef;
			ok($syscall_count > 0 && $firefox->quit() == 0, "Firefox (visible => 1) exited okay after $final successful $function calls");
			$success = 1;
		} or do {
			chomp $@;
			my $actual_error_message = $@;
			my $expected_error_message = quotemeta POSIX::strerror($expected_error_as_posix);
			ok($actual_error_message =~ /(?:$expected_error_message|[ ]exited[ ]with[ ]a[ ][1])/smx, "Firefox (visible => 1) failed with $function count set to $syscall_error_at_count:" . $actual_error_message);
			$syscall_error_at_count += 1;
		};
	}
}

sub finalise {
	my ($class) = @_;
	my $firefox = Firefox::Marionette->new(%parameters);
	ok($firefox->quit() == 0, "Firefox (visible => 1) exited okay when $function is reset");
	File::Path::rmtree( $base_directory, 0, 0 );

	done_testing();
}

1;
