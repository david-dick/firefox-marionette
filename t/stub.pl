#! /usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long();
use File::Spec();
use FileHandle();
use Fcntl();
use Socket();
use JSON();

MAIN: {
	my %options;
	Getopt::Long::GetOptions(\%options, 'version', 'marionette', 'headless', 'profile:s', 'no-remote', 'new-instance', 'devtools', 'safe-mode');
	my $browser_version = "112.0.2";
	if ($options{version}) {
		print "Mozilla Firefox $browser_version\n";
		exit 0;
	}
	socket my $server, Socket::PF_INET(), Socket::SOCK_STREAM(), 0 or die "Failed to create a socket:$!";
	bind $server, Socket::sockaddr_in( 0, Socket::INADDR_LOOPBACK() ) or die "Failed to bind socket:$!";
	listen $server, Socket::SOMAXCONN() or die "Failed to listen:$!";
	my $port = ( Socket::sockaddr_in( getsockname $server ) )[0];
	my $prefs_path = File::Spec->catfile($options{profile}, 'prefs.js');
	my $old_prefs_handle = FileHandle->new($prefs_path, Fcntl::O_RDONLY()) or die "Failed to open $prefs_path for reading:$!";
	my $new_prefs_path = File::Spec->catfile($options{profile}, 'prefs.new');
	my $new_prefs_handle = FileHandle->new($new_prefs_path, Fcntl::O_CREAT() | Fcntl::O_EXCL() | Fcntl::O_WRONLY(), Fcntl::S_IRUSR() | Fcntl::S_IWUSR()) or die "Failed to open $new_prefs_path for writing:$!";
	while(my $line = <$old_prefs_handle>) {
		if ($line =~ /^user_pref\("marionette.port",[ ]0\);/smx) {
			print {$new_prefs_handle} qq[user_pref("marionette.port", $port);\n] or die "Failed to write to $new_prefs_path:$!";	
		} else {
			print {$new_prefs_handle} $line or die "Failed to write to $new_prefs_path:$!";	
		}
	}
	close $new_prefs_handle or die "Failed to close $new_prefs_path:$!";
	close $old_prefs_handle or die "Failed to close $prefs_path:$!";
	rename $new_prefs_path, $prefs_path or die "Failed to rename $new_prefs_path to $prefs_path:$!";
	my $paddr = accept(my $client, $server);
	syswrite $client, qq[50:{"applicationType":"gecko","marionetteProtocol":3}] or die "Failed to write to socket:$!";
	my $request = _get_request($client);
	my $platform = $^O;
	my $headless = $options{headless} ? 'true' : 'false';
	my $response_type = 1;
	my $profile_path = $options{profile};
	$profile_path =~ s/\\/\\\\/smxg;
	my $capabilities = qq([1,1,null,{"sessionId":"5a5f9a08-0faa-4794-aa85-ee85980ce422","capabilities":{"browserName":"firefox","browserVersion":"$browser_version","platformName":"$platform","acceptInsecureCerts":false,"pageLoadStrategy":"normal","setWindowRect":true,"timeouts":{"implicit":0,"pageLoad":300000,"script":30000},"strictFileInteractability":false,"unhandledPromptBehavior":"dismiss and notify","moz:accessibilityChecks":false,"moz:buildID":"20230427144338","moz:headless":$headless,"moz:platformVersion":"6.2.14-200.fc37.x86_64","moz:processID":$$,"moz:profile":"$profile_path","moz:shutdownTimeout":60000,"moz:useNonSpecCompliantPointerOrigin":false,"moz:webdriverClick":true,"moz:windowless":false,"proxy":{}}}]);
	my $capability_length = length $capabilities;
	syswrite $client, $capability_length . q[:] . $capabilities or die "Failed to write to socket:$!";
	my $context = "content";
	while(1) {
		$request = _get_request($client);
		my $message_id = $request->[1];
		if ($request->[2] eq 'Marionette:Quit') {
			my $response_body = qq([$response_type,$message_id,null,{"cause":"shutdown","forced":false,"in_app":true}]);
			_send_response_body($client, $response_body);
			last;
		} elsif ($request->[2] eq 'Addon:Install') {
			syswrite $client, qq(79:[$response_type,$message_id,null,{"value":"6eea9fdc37a5d8fbcbbecd57ee7272669e828a31\@temporary-addon"}]) or die "Failed to write to socket:$!";
		} elsif ($request->[2] eq 'WebDriver:Print') {
			syswrite $client, qq(1475:[$response_type,$message_id,null,{"value":"JVBERi0xLjUKJbXtrvsKNCAwIG9iago8PCAvTGVuZ3RoIDUgMCBSCiAgIC9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp4nDNUMABCXUMgYW5ppJCcy1XIFahQyGVkoWdsaqQApUxNTfWMDQwVzI0hdFGqQrhCHpehAggWpSvoJxoopBcT1pTGFcgFACsfF2cKZW5kc3RyZWFtCmVuZG9iago1IDAgb2JqCiAgIDc1CmVuZG9iagozIDAgb2JqCjw8CiAgIC9FeHRHU3RhdGUgPDwKICAgICAgL2EwIDw8IC9DQSAxIC9jYSAxID4+CiAgID4+Cj4+CmVuZG9iago2IDAgb2JqCjw8IC9UeXBlIC9PYmpTdG0KICAgL0xlbmd0aCA3IDAgUgogICAvTiAxCiAgIC9GaXJzdCA0CiAgIC9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp4nD3NMQvCMBQE4L2/4hbnJlEUIXRoC8VBkOgmDiU+pEsSkkbsvzeJ1PG+d7wTYJWUqG+LI9SX8UXYgFdADp7MDA4GVeBMz2ls7Qf3RAx7LnA4CjzKsbNmTvWA3b8/eBsdpMwh599G0ZWuSf1ogstbeln5hNlHWlOXWj29J01qaDM2TfmvKNjoNQVsy2biL4KVMvQKZW5kc3RyZWFtCmVuZG9iago3IDAgb2JqCiAgIDE0NwplbmRvYmoKOCAwIG9iago8PCAvVHlwZSAvT2JqU3RtCiAgIC9MZW5ndGggMTEgMCBSCiAgIC9OIDMKICAgL0ZpcnN0IDE2CiAgIC9GaWx0ZXIgL0ZsYXRlRGVjb2RlCj4+CnN0cmVhbQp4nE2PTQvCMBBE7/kVc7NFaHZrxQ+kF8WLCCLexEOosQZKt6QR1F+vRgSvs/OWNwxSM4xJMYGnrBYL6MOjs9A7U9teAdAbd+5xRA7CHqcYLeXWBrAqy0jsvJxvlfVIKuO8gDOeZAWSawhdP9c6prU33dVVfSa+TtPvG29NkDe2ladrGoO18/Yi97+rk3ZlgkWymueUj2jMIybiohgyDYjSn8JXemmCaaSOeBwA/lh/Si9o4j6UCmVuZHN0cmVhbQplbmRvYmoKMTEgMCBvYmoKICAgMTgxCmVuZG9iagoxMiAwIG9iago8PCAvVHlwZSAvWFJlZgogICAvTGVuZ3RoIDU3CiAgIC9GaWx0ZXIgL0ZsYXRlRGVjb2RlCiAgIC9TaXplIDEzCiAgIC9XIFsxIDIgMl0KICAgL1Jvb3QgMTAgMCBSCiAgIC9JbmZvIDkgMCBSCj4+CnN0cmVhbQp4nBXKQQ0AIAwEwW1LCLyQgB1cIA8TeIPrZ7K5HPCe08CpYNxkJEdYEd6TmZemEG6xtMWGD8f2BIAKZW5kc3RyZWFtCmVuZG9iagpzdGFydHhyZWYKODYzCiUlRU9GCg=="}]) or die "Failed to write to socket:$!";
		} elsif ($request->[2] eq 'WebDriver:TakeScreenshot') {
			syswrite $client, qq(423:[$response_type,$message_id,null,{"value":"iVBORw0KGgoAAAANSUhEUgAABVYAAAAICAYAAAAShaQyAAAA8UlEQVR4Xu3YsQ0AIAwEMbL/0ICYgOud+isr1c2+txwBAgQIECBAgAABAgQIECBAgAABAgQIfAuMsPptZUiAAAECBAgQIECAAAECBAgQIECAAIEnIKx6BAIECBAgQIAAAQIECBAgQIAAAQIECEQBYTWCmRMgQIAAAQIECBAgQIAAAQIECBAgQEBY9QMECBAgQIAAAQIECBAgQIAAAQIECBCIAsJqBDMnQIAAAQIECBAgQIAAAQIECBAgQICAsOoHCBAgQIAAAQIECBAgQIAAAQIECBAgEAWE1QhmToAAAQIECBAgQIAAAQIECBAgQIAAgQMdMh/pgqHYUwAAAABJRU5ErkJggg=="}]) or die "Failed to write to socket:$!";
		} elsif ($request->[2] eq 'Marionette:GetContext') {
			my $response_body = qq([$response_type,$message_id,null,{"value":"$context"}]);
			_send_response_body($client, $response_body);
		} elsif ($request->[2] eq 'Marionette:SetContext') {
			my $response_body = qq([$response_type,$message_id,null,{"value":null}]);
			_send_response_body($client, $response_body);
		} elsif ($request->[2] eq 'WebDriver:ExecuteScript') {
			my $now = time;
			my $response_body = qq([$response_type,$message_id,null,{"value":{"guid":"root________","index":0,"type":2,"title":"","dateAdded":$now,"lastModified":$now,"childCount":5}}]);
			_send_response_body($client, $response_body);
		} else {
			die "Unsupported method in stub firefox";
		}
	}
	close $client or die "Failed to close socket:$!";
	exit 0;
}

sub _send_response_body {
	my ($client, $response_body) = @_;
	my $response_length = length $response_body;
	syswrite $client, qq(${response_length}:$response_body) or die "Failed to write to socket:$!";
}
sub _get_request {
	my ($client) = @_;
	my $length_buffer = q[];
	sysread $client, my $buffer, 1 or die "Failed to read from socket:$!";
	while($buffer ne q[:]) {
		$length_buffer .= $buffer;
		sysread $client, $buffer, 1 or die "Failed to read from socket:$!";
	}
	sysread $client, $buffer, $length_buffer or die "Failed to read from socket:$!";
	my $request = JSON->new()->utf8()->decode($buffer);
	return $request;
}
