#! /usr/bin/perl

use strict;
use warnings;
use DirHandle();
use File::HomeDir();
use File::Spec();
use File::Temp();
use FileHandle();
use IO::Socket();
use English qw( -no_match_vars );
use Text::CSV_XS();
use Cwd();
use POSIX();
use Config;

my $oldfh = select STDOUT; $OUTPUT_AUTOFLUSH = 1; select $oldfh;
$oldfh = select STDERR; $OUTPUT_AUTOFLUSH = 1; select $oldfh;

my @sig_names = split q[ ], $Config{sig_name};
our $start_time = time;
print "Start time is " . (localtime $start_time) . "\n";
if (exists $ENV{COUNT}) {
	$0 = "Test run number $ENV{COUNT}";
}
my $background_failed;
my $parent_pid = $PID;
my $devel_cover_db_format = 'JSON';
my $cover_db_name = 'cover_db';
my $devel_cover_inc = '-MDevel::Cover=-silent,1';
my $test_marionette_file = 't/01-marionette.t';
my $reset_time = 600; # 10 minutes
my $user = "dave";
$ENV{RELEASE_TESTING} = 1;
$ENV{FIREFOX_ALARM} = 600;
$ENV{DEVEL_COVER_DB_FORMAT} = $devel_cover_db_format;
system { 'cover' } 'cover', '-delete' and die "Failed to 'cover' for " . ($ENV{FIREFOX_BINARY} || 'firefox');
our $ping_pid;
MAIN: {
	my $cwd = Cwd::cwd();
	if ($ping_pid = fork) {
	} elsif (defined $ping_pid) {
		eval {
			exec { 'ping' } 'ping', '8.8.8.8' or die "Failed to exec ping:$EXTENDED_OS_ERROR";
		} or do {
			print STDERR $EVAL_ERROR;
		};
		exit 1;
	}
	my @servers;
        my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
	my $servers_path = $cwd . '/servers.csv';
	if (open my $handle, "<:encoding(utf8)", $servers_path) {
		my %headers;
		my $count = 0;
		foreach my $name ($csv->header($handle, { detect_bom => 1, munge_column_names => sub { lc (s/[ ]/_/grsmx ) }})) {
			$headers{$name} = $count;
			$count += 1;
		}
		while (my $row = $csv->getline ($handle)) {
			my $server = {};
			foreach my $key (sort { $a cmp $b } keys %headers) {
				$server->{$key} = $row->[$headers{$key}];
			}
			push @servers, $server;
		}
		close $handle or die "Failed to close $servers_path:$EXTENDED_OS_ERROR";
	} elsif ($OS_ERROR == POSIX::ENOENT()) {
	} else {
		die "Failed to open $servers_path for reading: $EXTENDED_OS_ERROR";
	}

	my $background_pids = {};
	foreach my $server (@servers) {
		if (my $pid = fork) {
			$background_pids->{$pid} = $server;
		} elsif (defined $pid) {
			eval {
				undef $ping_pid;
				my $win32_remote_alarm = 1800;
				my $win32_local_alarm = 600;
				$ENV{FIREFOX_ALARM} = $win32_remote_alarm;
				if ((lc $server->{type}) eq 'virsh') {
					if (_virsh_node_running($server)) {
						_execute($server, undef, 'sudo', 'virsh', 'shutdown', $server->{name});
						_sleep_until_shutdown($server);
					}
					_execute($server, undef, 'sudo', 'virsh', 'start', $server->{name});
					_determine_address($server);
					my $socket = _sleep_until_ssh_available($server);
					if ($socket) {
						close $socket;
						if ($server->{os} eq 'win32') {
							$server->{initial_command} = 'cd %TMP%';
							my $sleep_time = 30;
							_log_stderr($server, "Sleeping for $sleep_time seconds at " . localtime);
							sleep $sleep_time;
							_log_stderr($server, "Woken up at " . localtime);
							_cleanup_server($server);
							my $remote_tmp_directory = join q[], _remote_contents($server, undef, 'echo %TMP%');
							$remote_tmp_directory =~ s/[\r\n]+$//smx;
							$remote_tmp_directory =~ s/\\/\//smxg;
							if (!$remote_tmp_directory) {
								die "Unable to find remote temp directory";
							}
							my $cover_db_format = join q[], _remote_contents($server, undef, 'echo %DEVEL_COVER_DB_FORMAT%');
							$cover_db_format =~ s/[\r\n]+$//smx;
							$cover_db_format =~ s/\\/\//smxg;
							if ($cover_db_format ne $devel_cover_db_format) {
								die "Bad DEVEL_COVER_DB_FORMAT Environment variable";
							}
							my $count = 0;
							REMOTE_WIN32_FIREFOX: {
								local $ENV{FIREFOX_NO_RECONNECT} = 1;
								local $ENV{FIREFOX_NO_UPDATE} = 1;
								local $ENV{FIREFOX_USER} = $server->{user};
								local $ENV{FIREFOX_HOST} = $server->{address};
								$count += 1;
								my $start_execute_time = time;
								my $result = _execute($server, { return_result => 1 }, $^X, $devel_cover_inc, '-Ilib', $test_marionette_file);
								my $total_execute_time = time - $start_execute_time;
								if ($result != 0) {
									if ($count < 3) {
										my $error_message = _error_message($^X, $CHILD_ERROR);
										warn "Failed '$^X $devel_cover_inc -Ilib $test_marionette_file' with FIREFOX_USER=$server->{user} and FIREFOX_HOST=$server->{address} at " . localtime . " exited with a '$error_message' after $total_execute_time seconds.  Sleeping for $reset_time seconds";
										if (_restart_server($server, $count)) {
											redo REMOTE_WIN32_FIREFOX;
										} else {
											die "Failed to restart remote $server->{name} on time $count";
										}
									} else {
										die "Failed to make $count times";
									}
								}
							}
							_execute($server, undef, 'scp', '-r', '-P', $server->{port}, Cwd::cwd(), $server->{user} . q[@] . $server->{address} . q[:/] . $remote_tmp_directory);
							$server->{initial_command} .= "\\firefox-marionette";
							foreach my $command_line (
											"set FIREFOX_ALARM=$win32_local_alarm && set RELEASE_TESTING=1 && perl $devel_cover_inc -Ilib " . _win32_path($test_marionette_file),
											"set FIREFOX_ALARM=$win32_local_alarm && set FIREFOX_DEVELOPER=1 && set RELEASE_TESTING=1 && set FIREFOX_DEBUG=1 && perl $devel_cover_inc -Ilib " . _win32_path($test_marionette_file),
											"set FIREFOX_ALARM=$win32_local_alarm && set FIREFOX_NIGHTLY=1 && set RELEASE_TESTING=1 && perl $devel_cover_inc -Ilib " . _win32_path($test_marionette_file),
											"set FIREFOX_ALARM=$win32_local_alarm && set WATERFOX=1 && set RELEASE_TESTING=1 && perl $devel_cover_inc -Ilib " . _win32_path($test_marionette_file),
											"set FIREFOX_ALARM=$win32_local_alarm && set WATERFOX_VIA_FIREFOX=1 && set RELEASE_TESTING=1 && perl $devel_cover_inc -Ilib " . _win32_path($test_marionette_file),
											) {
								$count = 0;
								WIN32_FIREFOX: {
									$count += 1;
									my $start_execute_time = time;
									my $result = _remote_execute($server, { return_result => 1 }, $command_line);
									my $total_execute_time = time - $start_execute_time;
									if ($result != 0) {
										if ($count < 3) {
											my $error_message = _error_message('ssh', $CHILD_ERROR);
											warn "Failed '$command_line' at " . localtime . " exited with a '$error_message' after $total_execute_time seconds.  Sleeping for $reset_time seconds";
											if (_restart_server($server, $count)) {
												redo WIN32_FIREFOX;
											} else {
												die "Failed to restart local $server->{name} on time $count";
											}
										} else {
											die "Failed to make $count times";
										}
									}
								}
							}
							_execute($server, undef, 'scp', '-r', '-P', $server->{port}, $server->{user} . q[@] . $server->{address} . q[:/] . $remote_tmp_directory . q[/firefox-marionette/] . $cover_db_name, Cwd::cwd() . '/');
						}
						if ((lc $server->{type}) eq 'virsh') {
							_execute($server, undef, 'sudo', 'virsh', 'shutdown', $server->{name});
							_sleep_until_shutdown($server);
						}
					}
				} else {
					die "Unknown server type '$server->{type}' in $servers_path";
				}
				exit 0;
			} or do {
				_log_stderr($server, "Caught an exception while remote testing:$EVAL_ERROR");
				if ((lc $server->{type}) eq 'virsh') {
					_execute($server, undef, 'sudo', 'virsh', 'shutdown', $server->{name});
					_sleep_until_shutdown($server);
				}
			};
			exit 1;
		} else {
			die "Failed to fork:$EXTENDED_OS_ERROR";
		}
	}
	my $path = File::Spec->catdir(File::HomeDir::my_home(), 'den');
	my $initial_upgrade_package = 'firefox-52.0esr.tar.bz2';
	my $initial_upgrade_directory = 'firefox-upgrade';
	sub setup_upgrade {
		if (-e "$path/$initial_upgrade_package") {
			my $result = system "rm -Rf $path/firefox && rm -Rf $path/$initial_upgrade_directory && tar --directory $path -jxf $path/$initial_upgrade_package && mv $path/firefox $path/$initial_upgrade_directory";
			$result == 0 or die "Failed to setup $initial_upgrade_directory";
		}
	}
	setup_upgrade();
	my $handle = DirHandle->new($path);
	my @entries;
	if ($handle) {
		while(my $entry = $handle->read()) {
			next if ($entry eq File::Spec->updir());
			next if ($entry eq File::Spec->curdir());
			next if ($entry =~ /[.]tar[.]bz2$/smx);
			push @entries, $entry;
		}
	} else {
		warn "No firefox den at $path";
	}
	foreach my $entry (reverse sort { $a cmp $b } @entries) {
		my $entry_version;
		if ($entry =~ /^firefox\-([\d.]+)(?:esr|a\d+)?$/smx) {
			($entry_version) = ($1);
		} elsif ($entry eq 'firefox-nightly') {
		} elsif ($entry eq 'firefox-developer') {
		} elsif ($entry eq 'firefox-upgrade') {
		} elsif ($entry =~ /^waterfox/smx) {
		} else {
			die "Unrecognised entry '$entry' in $path";
		}
		if ($entry =~ /^waterfox/smx) {
		} elsif ($entry eq 'firefox-nightly') {
		} elsif ($entry eq 'firefox-developer') {
		} elsif ($entry eq 'firefox-upgrade') {
		} else {
			my $path_to_binary = File::Spec->catfile($path, $entry, 'firefox');
			my $old_version;
			my $old_output = `$path_to_binary --version 2>/dev/null`;
			if ($old_output =~ /^Mozilla[ ]Firefox[ ]([\d.]+)/smx) {
				($old_version) = ($1);
			} else {
				die "$path_to_binary old '$old_output' could not be parsed";
			}
			if ($old_version ne $entry_version) {
				die "$old_version does not equal $entry_version for $path_to_binary";
			}
		}
	}
	warn "Den is correct";
	my %old_versions;
	my %paths_to_binary;
	ENTRY: foreach my $entry (reverse sort { $a cmp $b } @entries) {
		my $entry_version;
		if ($entry =~ /^waterfox/smx) {
		} elsif ($entry eq 'firefox-nightly') {
		} elsif ($entry eq 'firefox-developer') {
		} elsif ($entry eq 'firefox-upgrade') {
		} elsif ($entry =~ /^firefox\-([\d.]+)(?:esr|a\d+)?$/smx) {
			($entry_version) = ($1);
		} else {
			die "Unrecognised entry '$entry' in $path";
		}
		my $path_to_binary;
		if ($entry =~ /^waterfox/smx) {
			$path_to_binary = File::Spec->catfile($path, $entry, 'waterfox');
		} else {
			$path_to_binary = File::Spec->catfile($path, $entry, 'firefox');
		}
		$paths_to_binary{$entry} = $path_to_binary;
		my $old_version;
		my $old_output = `$path_to_binary --version 2>/dev/null`;
		if ($entry =~ /^waterfox/smx) {
			$old_version = $old_output;
		} elsif ($old_output =~ /^Mozilla[ ]Firefox[ ]([\d.]+)/smx) {
			($old_version) = ($1);
		} else {
			die "$path_to_binary old '$old_output' could not be parsed";
		}
		if ($entry =~ /^waterfox/smx) {
		} elsif ($entry eq 'firefox-nightly') {
		} elsif ($entry eq 'firefox-developer') {
		} elsif ($entry eq 'firefox-upgrade') {
		} elsif ($old_version ne $entry_version) {
			die "$old_version does not equal $entry_version for $path_to_binary";
		}
		$old_versions{$entry} = $old_version;
	}
	if (@entries) {
		_multiple_attempts_execute($^X, [ $devel_cover_inc, '-Ilib', $test_marionette_file ], {});
		{
			local $ENV{FIREFOX_ALARM} = 1800;
			_multiple_attempts_execute($^X, [ $devel_cover_inc, '-Ilib', $test_marionette_file ], { FIREFOX_HOST => 'localhost' });
		}
	}
	_check_for_background_processes($background_pids);
	if (my $entry = $old_versions{'firefox-upgrade'}) {
		setup_upgrade();
		if (defined $paths_to_binary{$entry}) {
			{
				local $ENV{FIREFOX_ALARM} = 2700;
				_multiple_attempts_execute($^X, [ $devel_cover_inc, '-Ilib', $test_marionette_file ], { FIREFOX_HOST => 'localhost', FIREFOX_BINARY => $paths_to_binary{$entry} });
			}
		}
	}
	_check_for_background_processes($background_pids);
	my $firefox_nightly_failed;
	ENTRY: foreach my $entry (reverse sort { $a cmp $b } @entries) {
		my $old_version = $old_versions{$entry};
		my $count = 0;
		my $path_to_binary = $paths_to_binary{$entry};
		$ENV{FIREFOX_BINARY} = $path_to_binary;
		if ($entry =~ /^waterfox/smx) {
			_multiple_attempts_execute($^X, [ $devel_cover_inc, '-Ilib', $test_marionette_file ], { WATERFOX => 1, FIREFOX_BINARY => $paths_to_binary{$entry} });
			_multiple_attempts_execute($^X, [ $devel_cover_inc, '-Ilib', $test_marionette_file ], { WATERFOX_VIA_FIREFOX => 1, FIREFOX_BINARY => $paths_to_binary{$entry} });
		}
		if (-e $ENV{FIREFOX_BINARY}) {
			$count = 0;
			LOCAL: {
				$count += 1;
				my $start_execute_time = time;
				my $result = system { $^X } $^X, $devel_cover_inc, '-Ilib', $test_marionette_file;
				my $total_execute_time = time - $start_execute_time;
				if ($result != 0) {
					if ($count < 3) {
						my $error_message = _error_message($^X, $CHILD_ERROR);
						warn "Failed '$^X $devel_cover_inc -Ilib $test_marionette_file with FIREFOX_BINARY=$ENV{FIREFOX_BINARY} at ' " . localtime . " exited with a '$error_message' after $total_execute_time seconds.  Sleeping for $reset_time seconds for $path_to_binary";
						if ($entry eq 'firefox-nightly') {
							$firefox_nightly_failed = 1;
							next ENTRY;
						}
						sleep $reset_time;
						redo LOCAL;
					} else {
						die "Failed to make $count times";
					}
				}
			}
			if ($entry eq 'firefox-upgrade') {
				setup_upgrade();
			}
			my $bash_command = 'cd ' . Cwd::cwd() . '; FIREFOX_ALARM=' . $ENV{FIREFOX_ALARM} . ' DEVEL_COVER_DB_FORMAT=' . $devel_cover_db_format . ' RELEASE_TESTING=1 FIREFOX_BINARY="' . $ENV{FIREFOX_BINARY} . "\" $^X $devel_cover_inc -Ilib $test_marionette_file";
			if ($entry eq 'firefox-nightly') {
				if (!_multiple_attempts_execute('ssh', [ 'localhost', $bash_command ], undef, 1)) {
					$firefox_nightly_failed = 1;
					next ENTRY;
				}
			} else {
				_multiple_attempts_execute('ssh', [ 'localhost', $bash_command ]);
			}
			if ($entry eq 'firefox-upgrade') {
				setup_upgrade();
			}
			$bash_command = 'cd ' . Cwd::cwd() . '; FIREFOX_ALARM=' . $ENV{FIREFOX_ALARM} . ' DEVEL_COVER_DB_FORMAT=' . $devel_cover_db_format . ' RELEASE_TESTING=1 FIREFOX_VISIBLE=1 FIREFOX_BINARY="' . $ENV{FIREFOX_BINARY} . "\" $^X $devel_cover_inc -Ilib $test_marionette_file";
			if ($entry eq 'firefox-nightly') {
				if (!_multiple_attempts_execute('ssh', [ 'localhost', $bash_command ], undef, 1)) {
					$firefox_nightly_failed = 1;
					next ENTRY;
				}
			} else {
				_multiple_attempts_execute('ssh', [ 'localhost', $bash_command ]);
			}
		}
		my $new_version;
		my $new_output = `$path_to_binary --version 2>/dev/null`;
		if ($entry =~ /^waterfox/smx) {
			$new_version = $new_output;
		} elsif ($new_output =~ /^Mozilla[ ]Firefox[ ]([\d.]+)/smx) {
			($new_version) = ($1);
		} else {
			die "$path_to_binary new '$new_output' could not be parsed";
		}
		if ($entry eq 'firefox-nightly') {
		} elsif ($entry eq 'firefox-developer') {
		} elsif ($entry eq 'firefox-upgrade') {
		} elsif ($entry eq 'waterfox') {
		} elsif ($old_version ne $new_version) {
			die "$old_version changed to $new_version for $path_to_binary";
		}
		_check_for_background_processes($background_pids);
	}
	while (_check_for_background_processes($background_pids)) {
		sleep 10;
	}
	while (kill 0, $ping_pid) {
		kill 'TERM', $ping_pid;
		waitpid $ping_pid, POSIX::WNOHANG();
	}
	undef $ping_pid;
	chdir $cwd or die "Failed to chdir to '$cwd':$EXTENDED_OS_ERROR";
	if (-d "$cwd/$cover_db_name") {
		$ENV{DEVEL_COVER_DB_FORMAT} = $devel_cover_db_format;
		system { 'cover' } 'cover' and die "Failed to 'cover'";
	} else {
		warn "No coverage generated\n";
	}
	if ($background_failed) {
		warn "Background processes failed to complete successfully\n";
	}
	if ($firefox_nightly_failed) {
		warn "Firefox Nightly failed to complete successfully\n";
	} else {
		warn "Firefox Nightly PASSED successfully\n";
	}
}

sub _restart_server {
	my ($server, $count) = @_;
	_log_stderr($server, "Restarting $server->{name} at " . localtime);
	if (my $pid = fork) {
		my $start_time = time;
		waitpid $pid, 0;
		_log_stderr($server, "Restart sub process completed after " . (time - $start_time) . " seconds at " . localtime);
		if ($CHILD_ERROR != 0) {
			die "Restart process failed to complete successfully:" . _error_message('Restart process', $CHILD_ERROR);
		}
		_log_stderr($server, "Restart successfull at " . localtime);
	} elsif (defined $pid) {
		eval {
			_execute($server, undef, 'sudo', 'virsh', 'shutdown', $server->{name});
			_sleep_until_shutdown($server);
			_execute($server, undef, 'sudo', 'virsh', 'start', $server->{name});
			_determine_address($server);
			my $socket = _sleep_until_ssh_available($server);
			if ($socket) {
				close $socket;
				exit 0;
			} else {
				_log_stderr($server, "Failed to contact $server->{name} on restart $count");
				_execute($server, undef, 'sudo', 'virsh', 'shutdown', $server->{name});
			}
			0;
		} or do {
			_log_stderr($server, "Caught an exception while restarting $server->{address}:$EVAL_ERROR");
		};
		exit 1;
	}
}

sub _check_for_background_processes {
	my ($background_pids) = @_;
	foreach my $pid (sort { $a <=> $b } keys %{$background_pids}) {
		my $result = waitpid $pid, POSIX::WNOHANG();
		if ($result == $pid) {
			delete $background_pids->{$pid};
			if ($CHILD_ERROR) {
				$background_failed = 1;
			}
		} elsif ($result == -1) {
			warn "Background process $pid has already been reaped at " . localtime  . "\n";
			delete $background_pids->{$pid};
		} else {
			return 1;
		}
	}
	return 0;
}

sub _test_description {
	my ($command, $arguments, $env) = @_;
	my $description = q['] . (join q[ ], $command, @{$arguments}) . q['];
	if ((ref $env) && (keys %{$env})) {
		$description .= q[ with ] . join q[ and ], map { "$_=$env->{$_}" } sort { $a cmp $b } keys %{$env};
	}
	return $description;
}

sub _multiple_attempts_execute {
	my ($command, $arguments, $env, $skip_on_fail) = @_;
	local %ENV = %ENV;
	my $count = 0;
	ATTEMPT: {
		foreach my $key (sort { $a cmp $b } keys %{$env}) {
			$ENV{$key} = $env->{$key};
		}
		$count += 1;
		my $start_execute_time = time;
		my $result = system { $command } $command, @{$arguments};
		my $total_execute_time = time - $start_execute_time;
		if ($result != 0) {
			if ($count < 3) {
				my $error_message = _error_message($command, $CHILD_ERROR);
				warn q[Failed ] . _test_description($command, $arguments, $env) . q[ at ] . localtime . " exited with a '$error_message' after $total_execute_time seconds.  Sleeping for $reset_time seconds";
				sleep $reset_time;
				redo ATTEMPT;
			} else {
				die q[Failed to ] . _test_description($command, $arguments, $env) . " $count times";
			}
		}
	}
	return 1;
}

sub _win32_path {
	my ($unix_path) = @_;
	my $windows_path = join q[\\], split /[\/]/smx, $unix_path;
	return $windows_path;
}

sub _check_parent_alive {
	if (!kill 0, $parent_pid) {
		die "Parent ($parent_pid) is no longer running.  Terminating\n";
	}
}

sub _sleep_until_shutdown {
	my ($server) = @_;
	while (_virsh_node_running($server)) {
		_log_stderr($server, "Waiting for $server->{name} to shutdown");
		sleep 1;
	}
	return;
}

sub _determine_address {
	my ($server) = @_;
	if (!$server->{address}) {
		my $address;
		while(!($address = _get_address($server))) {
			if (_virsh_node_running($server)) {
				_log_stderr($server, "Waiting for $server->{name} to get an IP address");
				sleep 1;
			} else {
				return;
			}
		}
		$server->{address} = $address;
	}
	if (!$server->{port}) {
		$server->{port} = 22;
	}
}

sub _sleep_until_ssh_available {
	my ($server) = @_;
	my $client_socket;
	while(!($client_socket = IO::Socket->new(
		Domain => IO::Socket::AF_INET(),
		Type => IO::Socket::SOCK_STREAM(),
		proto => 'tcp',
		PeerPort => 22,
		PeerHost => $server->{address},
				   ))) {
		if (_virsh_node_running($server)) {
			_log_stderr($server, "Waiting for $server->{name} to start the ssh server");
			sleep 1;
		} else {
			_log_stderr($server, "Server $server->{name} has stopped running while waiting for ssh server to start");
			return;
		}
	}
	_log_stderr($server, "$server->{name} has started the ssh server");
	return $client_socket;
}

sub _virsh_node_running {
	my ($server) = @_;
	my $running = 0;
	foreach my $line (_contents($server, undef, 'sudo', 'virsh','list', '--name')) {
		if ($line =~ /^\s*$server->{name}\s*$/smx) {
			$running = 1;
		}
	}
	return $running;
}

sub _cleanup_server {
	my ($server) = @_;
	my $parameters;
	foreach my $line (_list_remote_tmp_directory($server)) {
		if ($line =~ /^(firefox\-marionette)\s*$/smx) {
			_rmdir($server, $1);
		} elsif ($line =~ /^(firefox_marionette_selfie_\S+)\s*$/smx) {
			_unlink($server, $1);
		} elsif ($line =~ /^(firefox_marionette_\S+)\s*$/smx) {
			_rmdir($server, $1);
		} elsif ($line =~ /^(firefox_test_part_cert_\S+)\s*$/smx) {
			_unlink($server, $1);
		} elsif ($line =~ /^(firefox_test_part_cert_\S+)\s*$/smx) {
			_unlink($server, $1);
		} elsif ($line =~ /^(tmpaddon\S*)\s*$/smx) {
			_unlink($server, $1);
		} elsif ($line =~ /^(mozilla\-temp\-files)\s*$/smx) {
			_rmdir($server, $1);
		} elsif ($line =~ /^(MozillaBackgroundTask\S+backgroundupdate\S*)\s*$/smx) {
			_rmdir($server, $1);
		}
	}
}

sub _unlink {
	my ($server, $filename) = @_;
	_remote_execute($server, undef, 'del /f /q ' . $filename);
}

sub _rmdir {
	my ($server, $directory) = @_;
	_remote_execute($server, undef, 'rmdir /s /q ' . $directory);
}

sub _execute {
	my ($server, $parameters, $command, @arguments) = @_;
	return _contents($server, $parameters, $command, @arguments);
}

sub _remote_execute {
	my ($server, $parameters, $remote_command_line) = @_;
	return _remote_contents($server, $parameters, $remote_command_line);
}

sub _remote_contents {
	my ($server, $parameters, $remote_command_line) = @_;
	return _contents($server, $parameters, 'ssh', _ssh_parameters(), _server_address($server), join q[ && ], grep { defined } $server->{initial_command}, $remote_command_line);
}

sub _ssh_parameters {
	return (
            '-2',
            '-o',    'BatchMode=yes',
            '-o',    'ServerAliveCountMax=5',
            '-o',    'ServerAliveInterval=3',
		);
}

sub _server_address {
	my ($server) = @_;
	return ('-p', $server->{port}, $server->{user} . q[@] . $server->{address});
}

sub _list_remote_tmp_directory {
	my ($server) = @_;
	return _remote_contents($server, undef, 'dir /B');
}

sub _get_address {
	my ($server) = @_;
	my $address;
	foreach my $line (_contents($server, undef, 'sudo', 'virsh', 'domifaddr', $server->{name})) {
		if ($line =~ /^\s+\w+\s+[a-f0-9:]+\s+ipv4\s+([\d.]+)\/24\s*$/smx) {
			($address) = ($1);
		}
	}
	return $address;
}

sub _prefix {
	my ($server) = @_;
	return $server->{name} . ' --> ';
}

sub _log_stderr {
	my ($server, $message) = @_;
	print {*STDERR} _prefix($server) . "$message\n" or die "Failed to print to STDERR:$EXTENDED_OS_ERROR";
}

sub _log_stdout {
	my ($server, $message) = @_;
	print _prefix($server) . "$message\n" or die "Failed to print to STDOUT:$EXTENDED_OS_ERROR";
}

sub _contents {
	my ($server, $parameters, $command, @arguments) = @_;
	_check_parent_alive();
	my @lines;
	my $return_result;
	my $handle = FileHandle->new();
	if (my $pid = $handle->open(q[-|])) {
		while(my $line = <$handle>) {
			chomp $line;
			_check_parent_alive();
			_log_stdout($server, $line);
			push @lines, $line;
		}
		my $result = close $handle;
		if ($result == 1) {
			$return_result = 0;
		} else {
			if ($ERRNO == 0) {
				warn "Command " . (join q[ ], $command, @arguments) . " failed to close successfully:" . _error_message($command, $CHILD_ERROR);
			} else {
				warn "Command " . (join q[ ], $command, @arguments) . " failed to cleanup successfully:$!:";
			}
			$return_result = 1;
		}
	} else {
		eval {
			open STDERR, '<&=', fileno STDOUT or die "Failed to redirect STDERR:$EXTENDED_OS_ERROR";
			exec { $command } $command, @arguments or die "Failed to exec $command:$EXTENDED_OS_ERROR";
		} or do {
			_log_stderr($server, q[Caught an exception while running '] . (join q[ ], $command, @arguments) . "':$EVAL_ERROR");
		};
		exit 1;
	}
	if ($parameters->{return_result}) {
		return $return_result;
	} else {
		return @lines;
	}
}

sub _signal_name {
    my ( $number ) = @_;
    return $sig_names[$number];
}

sub _error_message {
	my ($binary, $child_error) = @_;
	my $message;
	if ((POSIX::WIFEXITED($child_error)) || (POSIX::WIFSIGNALED($child_error))) {
		if ( POSIX::WIFEXITED($child_error) ) {
			$message = $binary . ' exited with a ' . POSIX::WEXITSTATUS($child_error);
		} elsif (POSIX::WIFSIGNALED($child_error)) {
			my $name = _signal_name( POSIX::WTERMSIG($child_error) );
			if ( defined $name ) {
				$message = "$binary killed by a $name signal (" . POSIX::WTERMSIG($child_error) . q[)];
			} else {
				$message = "$binary killed by a signal (" . POSIX::WTERMSIG($child_error) . q[)];
			}
		}
	}
	return $message;
}

END {
	if (defined $ping_pid) {
		while (kill 0, $ping_pid) {
			kill 'TERM', $ping_pid;
			waitpid $ping_pid, POSIX::WNOHANG();
		}
	}
	my $end_time = time;
	my ($hours, $minutes, $seconds) = (0,0,$end_time - $start_time);
	while($seconds >= 3600) {
		$seconds -= 3600;
		$hours += 1;
	}
	while($seconds >= 60) {
		$seconds -= 60;
		$minutes += 1;
	}
	print "Run took $hours hours, $minutes minutes and $seconds seconds\n";
	print "End time is " . (localtime $end_time) . "\n";
}
