#! /usr/bin/perl -w

use strict;
use Firefox::Marionette();
use Test::More;
use HTTP::Daemon();
use Socket();
use Config;
use Fcntl();
use File::Temp();
use URI();
use IO::Socket::IP();
use POSIX();

my $is_covering = !!(eval 'Devel::Cover::get_coverage()');
my @sig_nums  = split q[ ], $Config{sig_num};
my @sig_names = split q[ ], $Config{sig_name};
my %signals_by_name;
my $idx = 0;
foreach my $sig_name (@sig_names) {
	$signals_by_name{$sig_name} = $sig_nums[$idx];
	$idx += 1;
}

$SIG{INT} = sub { die "Caught an INT signal"; };
$SIG{TERM} = sub { die "Caught a TERM signal"; };

SKIP: {
	if (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} ne 'localhost')) {
		diag("file upload testing is not supported for remote hosts");
		skip("file upload testing is not supported for remote hosts", 1);
	} elsif (($ENV{FIREFOX_HOST}) && ($ENV{FIREFOX_HOST} eq 'localhost') && ($ENV{FIREFOX_PORT})) {
		diag("file upload testing is not supported for remote hosts");
		skip("file upload testing is not supported for remote hosts", 1);
	} elsif (($^O eq 'cygwin') && ($^O eq 'MSWin32')) {
		diag("file upload testing is not supported for $^O");
		skip("file upload testing is not supported for $^O", 1);
	} elsif ((exists $Config::Config{'d_fork'}) && (defined $Config::Config{'d_fork'}) && ($Config::Config{'d_fork'} eq 'define')) {
		if ($ENV{RELEASE_TESTING}) {
			my $address = '127.0.0.1';
			my $daemon = HTTP::Daemon->new(LocalAddr => $address) || die "Failed to create HTTP::Daemon";
			my $port = URI->new($daemon->url())->port();
			my $debug = $ENV{FIREFOX_DEBUG} || 0;
			my $visible = $ENV{FIREFOX_VISIBLE} || 0;
			my @extra_parameters;
			if ($ENV{FIREFOX_BINARY}) {
				push @extra_parameters, (binary => $ENV{FIREFOX_BINARY});
			}
			my $handle = File::Temp->new( TEMPLATE => File::Spec->catfile( File::Spec->tmpdir(), 'firefox_test_proxy_XXXXXXXXXXX')) or Firefox::Marionette::Exception->throw( "Failed to open temporary file for writing:$!");
			fcntl $handle, Fcntl::F_SETFD(), 0 or Carp::croak("Can't clear close-on-exec flag on temporary file:$!");
			my $txt_document = q[success];
			if (my $pid = fork) {
				my $firefox = Firefox::Marionette->new(
					debug => $debug,
					visible => $visible,
					devtools => $debug && $visible,
					@extra_parameters,
							);
				ok($firefox, "Created a firefox object");
				wait_for_server_on($daemon, $daemon->url(), $pid);
				$daemon = undef;
				ok($firefox->go("http://$address:" . $port . "/showform"), "Retrieved webpage with file upload");
				my $upload_path = Cwd::cwd() . '/t/04-uploads.t';
				$firefox->find_id('addfile')->type($upload_path);
				$firefox->find_id('clickme')->click();
				my $upload_size = -s $upload_path;
				$firefox->strip() =~ /has[ ](\d+)[ ]bytes/smx;
				my $received_size = $1;
				ok($upload_size > 0 && defined $received_size && $received_size > 0 && $upload_size < $received_size, "File successfully uploaded:$upload_size < $received_size");
				ok($firefox->quit() == 0, "Firefox has closed with an exit status of 0:" . $firefox->child_error());
				while(kill 0, $pid) {
					kill $signals_by_name{TERM}, $pid;
					sleep 1;
					waitpid $pid, POSIX::WNOHANG();
				}
				ok($! == POSIX::ESRCH(), "Process $pid no longer exists:$!");
			} elsif (defined $pid) {
				eval 'Devel::Cover::set_coverage("none")' if $is_covering;
				eval {
					local $SIG{ALRM} = sub { die "alarm during proxy server\n" };
					alarm 40;
					$0 = "[Test HTTP Proxy for " . getppid . "]";
					diag("Accepting connections for $0");
					while (my $connection = $daemon->accept()) {
						diag("Accepted connection");
						while (my $request = $connection->get_request()) {
							diag("Got request for " . $request->uri());
							my ($headers, $response);
							if ($request->uri() =~ /showform/) {
								$headers = HTTP::Headers->new('Content-Type', 'text/html');
								$response = HTTP::Response->new(200, "OK", $headers, '<!DOCTYPE html><html lang="en-AU"><head><title>form submission</title></head><body><form accept-charset="UTF-8" method="post" enctype="multipart/form-data" action="upload"><input id="addfile" name="file_name_needed_for_upload" type="file"><input id="clickme" type="submit"></form></body></html>');
							} elsif ($request->uri() =~ /upload/) {
								$headers = HTTP::Headers->new('Content-Type', 'text/plain');
								$response = HTTP::Response->new(200, "OK", $headers, "Content body has " . (length $request->content()) . " bytes");
							} else {
								$response = HTTP::Response->new(200, "OK", undef, 'hello world');
							}
							$connection->send_response($response);
							last;
						}
						$connection->close;
						$connection = undef;
					}
				} or do {
					chomp $@;
					diag("Caught exception in proxy server:$@");
				};
				exit 1;
			} else {
				diag("Failed to fork http proxy:$!");
				die "Failed to fork:$!";
			}
		}
	} else {
		skip("No forking available for $^O", 1);
		diag("No forking available for $^O");
	}
}

done_testing();

sub wait_for_server_on {
	my ($daemon, $url, $pid) = @_;
	my $host = URI->new($url)->host();
	my $port = URI->new($url)->port();
	undef $daemon;
	CONNECT: while (!IO::Socket::IP->new(Type => Socket::SOCK_STREAM(), PeerPort => $port, PeerHost => $host)) {
		diag("Waiting for server ($pid) to listen on $host:$port:$!");
		waitpid $pid, POSIX::WNOHANG();
		if (kill 0, $pid) {
			sleep 1;
		} else {
			diag("Server ($pid) has exited");
			last CONNECT;
		}
	}
	return 
}

