package Firefox::Marionette;

use warnings;
use strict;
use Firefox::Marionette::Response();
use Firefox::Marionette::Element();
use Firefox::Marionette::Cookie();
use Firefox::Marionette::Window::Rect();
use Firefox::Marionette::Element::Rect();
use Firefox::Marionette::Timeouts();
use Firefox::Marionette::Capabilities();
use Firefox::Marionette::Profile();
use Firefox::Marionette::Proxy();
use Firefox::Marionette::Exception();
use Firefox::Marionette::Exception::Response();
use Compress::Zlib();
use Config::INI::Reader();
use Archive::Zip();
use Symbol();
use JSON();
use IPC::Open3();
use Socket();
use English qw( -no_match_vars );
use POSIX();
use File::Find();
use File::Path();
use File::Spec();
use URI();
use URI::Escape();
use Time::HiRes();
use File::Temp();
use File::stat();
use FileHandle();
use MIME::Base64();
use DirHandle();
use Carp();
use Config;
use base qw(Exporter);

BEGIN {
    if ( $OSNAME eq 'MSWin32' ) {
        require Win32;
        require Win32::Process;
        require Win32API::Registry;
    }
}

our @EXPORT_OK =
  qw(BY_XPATH BY_ID BY_NAME BY_TAG BY_CLASS BY_SELECTOR BY_LINK BY_PARTIAL);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

our $VERSION = '1.00_03';

sub _ANYPROCESS                     { return -1 }
sub _COMMAND                        { return 0 }
sub _DEFAULT_HOST                   { return 'localhost' }
sub _MARIONETTE_PROTOCOL_VERSION_3  { return 3 }
sub _WIN32_ERROR_SHARING_VIOLATION  { return 0x20 }
sub _NUMBER_OF_MCOOKIE_BYTES        { return 16 }
sub _MAX_DISPLAY_LENGTH             { return 10 }
sub _NUMBER_OF_TERM_ATTEMPTS        { return 4 }
sub _MAX_VERSION_FOR_ANCIENT_CMDS   { return 31 }
sub _MAX_VERSION_FOR_NEW_CMDS       { return 61 }
sub _MIN_VERSION_FOR_NEW_SENDKEYS   { return 55 }
sub _MIN_VERSION_FOR_HEADLESS       { return 55 }
sub _MIN_VERSION_FOR_WD_HEADLESS    { return 56 }
sub _MIN_VERSION_FOR_SAFE_MODE      { return 55 }
sub _MIN_VERSION_FOR_MODERN_EXIT    { return 40 }
sub _MIN_VERSION_FOR_AUTO_LISTEN    { return 55 }
sub _MIN_VERSION_FOR_HOSTPORT_PROXY { return 57 }
sub _MIN_VERSION_FOR_XVFB           { return 12 }
sub _DEFAULT_SOCKS_VERSION          { return 5 }
sub _MILLISECONDS_IN_ONE_SECOND     { return 1_000 }
sub _DEFAULT_PAGE_LOAD_TIMEOUT      { return 300_000 }
sub _DEFAULT_SCRIPT_TIMEOUT         { return 30_000 }
sub _DEFAULT_IMPLICIT_TIMEOUT       { return 0 }
sub _WIN32_CONNECTION_REFUSED       { return 10_061 }
sub _OLD_PROTOCOL_NAME_INDEX        { return 2 }
sub _OLD_PROTOCOL_PARAMETERS_INDEX  { return 3 }
sub _OLD_INITIAL_PACKET_SIZE        { return 66 }
sub _READ_LENGTH_OF_OPEN3_OUTPUT    { return 50 }
sub _DEFAULT_WINDOW_WIDTH           { return 1024 }
sub _DEFAULT_WINDOW_HEIGHT          { return 768 }
sub _DEFAULT_DEPTH                  { return 24 }
sub _LOCAL_READ_BUFFER_SIZE         { return 8192 }
sub _WIN32_PROCESS_INHERIT_FLAGS    { return 0 }

sub _WATERFOX_CURRENT_VERSION_EQUIV {
    return 68;
}    # https://github.com/MrAlex94/Waterfox/wiki/Versioning-Guidelines

sub _WATERFOX_CLASSIC_VERSION_EQUIV {
    return 56;
}    # https://github.com/MrAlex94/Waterfox/wiki/Versioning-Guidelines

my $proxy_name_regex = qr/perl_ff_m_\w+/smx;
my $local_name_regex = qr/firefox_marionette_local_\w+/smx;
my $tmp_name_regex   = qr/firefox_marionette_(?:remote|local)_\w+/smx;

sub BY_XPATH {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_XPATH()) HAS BEEN REPLACED BY find ****'
    );
    return 'xpath';
}

sub BY_ID {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_ID()) HAS BEEN REPLACED BY find_id ****'
    );
    return 'id';
}

sub BY_NAME {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_NAME()) HAS BEEN REPLACED BY find_name ****'
    );
    return 'name';
}

sub BY_TAG {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_TAG()) HAS BEEN REPLACED BY find_tag ****'
    );
    return 'tag name';
}

sub BY_CLASS {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_CLASS()) HAS BEEN REPLACED BY find_class ****'
    );
    return 'class name';
}

sub BY_SELECTOR {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_SELECTOR()) HAS BEEN REPLACED BY find_selector ****'
    );
    return 'css selector';
}

sub BY_LINK {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_LINK()) HAS BEEN REPLACED BY find_link ****'
    );
    return 'link text';
}

sub BY_PARTIAL {
    Carp::carp(
'**** DEPRECATED METHOD - using find(..., BY_PARTIAL()) HAS BEEN REPLACED BY find_partial ****'
    );
    return 'partial link text';
}

sub _download_directory {
    my ($self) = @_;
    my $directory;
    eval {
        my $context = $self->context();
        $self->context('chrome');
        $directory =
          $self->script( 'var branch = Components.classes["' . q[@]
              . 'mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch(""); return branch.getStringPref ? branch.getStringPref("browser.download.downloadDir") : branch.getComplexValue("browser.download.downloadDir", Components.interfaces.nsISupportsString).data;'
          );
        $self->context($context);
    } or do {
        chomp $EVAL_ERROR;
        Carp::carp(
"Firefox does not support dynamically determining download directory:$EVAL_ERROR"
        );
        my $profile =
          Firefox::Marionette::Profile->parse(
            File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' ) );
        $directory = $profile->get_value('browser.download.downloadDir');
    };
    if ( $OSNAME eq 'cygwin' ) {
        $directory = $self->execute( 'cygpath', '-s', '-m', $directory );
    }
    return $directory;
}

sub mime_types {
    my ($self) = @_;
    return @{ $self->{mime_types} };
}

sub download {
    my ( $self, $path ) = @_;
    my $handle;
    if ( my $ssh = $self->_ssh() ) {
        $handle = $self->_get_file_via_scp( $path, 'downloaded file' );
    }
    else {
        $handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
          or Firefox::Marionette::Exception->throw(
            "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
    }
    return $handle;
}

sub _directory_listing_via_ssh {
    my ( $self, $directory ) = @_;
    my $binary    = 'ls';
    my @arguments = ( '-1', "\"$directory\"" );

    if ( $self->_remote_uname() eq 'MSWin32' ) {
        $binary    = 'dir';
        @arguments = ( '/B', $directory );
    }
    my @entries;
    foreach my $entry ( split /\r?\n/smx,
        $self->_execute_via_ssh( {}, $binary, @arguments ) )
    {
        push @entries, $self->_remote_catfile( $directory, $entry );
    }
    return @entries;
}

sub _directory_listing {
    my ( $self, $directory ) = @_;
    my @entries;
    if ( my $ssh = $self->_ssh() ) {
        @entries = $self->_directory_listing_via_ssh($directory);
    }
    else {
        my $handle = DirHandle->new($directory)
          or Firefox::Marionette::Exception->throw(
            "Failed to open directory '$directory':$EXTENDED_OS_ERROR");
        while ( my $entry = $handle->read() ) {
            next if ( $entry eq File::Spec->updir() );
            next if ( $entry eq File::Spec->curdir() );
            push @entries, File::Spec->catfile( $directory, $entry );
        }
        $handle->close()
          or Firefox::Marionette::Exception->throw(
            "Failed to close directory '$directory':$EXTENDED_OS_ERROR");
    }
    return @entries;
}

sub downloading {
    my ($self) = @_;
    my $downloading = 0;
    foreach
      my $entry ( $self->_directory_listing( $self->_download_directory() ) )
    {
        if ( $entry =~ /[.]part$/smx ) {
            $downloading = 1;
            Carp::carp("Waiting for $entry to download");
        }
    }
    return $downloading;
}

sub downloads {
    my ($self) = @_;
    return $self->_directory_listing( $self->_download_directory() );
}

sub _setup_adb {
    my ( $self, $host ) = @_;
    $self->{_adb} = { host => $host, };
    return;
}

sub _read_possible_proxy_path {
    my ( $self, $path ) = @_;
    my $local_proxy_handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
      or return;
    my $result;
    my $search_contents;
    while ( $result =
        $local_proxy_handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() ) )
    {
        $search_contents .= $buffer;
    }
    defined $result
      or Firefox::Marionette::Exception->throw(
        "Failed to read from '$path':$EXTENDED_OS_ERROR");
    $local_proxy_handle->close()
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$path':$EXTENDED_OS_ERROR");
    my $local_proxy = JSON::decode_json($search_contents);
    return $local_proxy;
}

sub _matching_remote_proxy {
    my ( $self, $ssh_local_directory, $search_local_proxy ) = @_;
    my $local_proxy = $self->_read_possible_proxy_path(
        File::Spec->catfile( $ssh_local_directory, 'reconnect' ) );
    my $matched = 1;
    if ( !defined $local_proxy->{ssh} ) {
        return;
    }
    foreach my $key ( sort { $a cmp $b } keys %{$search_local_proxy} ) {
        if ( !defined $local_proxy->{ssh}->{$key} ) {
            $matched = 0;
        }
        elsif ( $key eq 'port' ) {
            if ( $local_proxy->{ssh}->{$key} != $search_local_proxy->{$key} ) {
                $matched = 0;
            }
        }
        else {
            if ( $local_proxy->{ssh}->{$key} ne $search_local_proxy->{$key} ) {
                $matched = 0;
            }

        }
    }
    if ($matched) {
        return $local_proxy;
    }
    return;
}

sub _get_max_scp_file_index {
    my ( $self, $directory_path ) = @_;
    my $directory_handle = DirHandle->new($directory_path)
      or Firefox::Marionette::Exception->throw(
        "Failed to open directory '$directory_path':$EXTENDED_OS_ERROR");
    my $maximum_index;
    while ( my $entry = $directory_handle->read() ) {
        if ( $entry =~ /^file_(\d+)[.]dat/smx ) {
            my ($index) = ($1);
            if ( ( defined $maximum_index ) && ( $maximum_index > $index ) ) {
            }
            else {
                $maximum_index = $index;
            }
        }
    }
    $directory_handle->close()
      or Firefox::Marionette::Exception->throw(
        "Failed to close directory '$directory_path':$EXTENDED_OS_ERROR");
    return $maximum_index;
}

sub _setup_ssh_with_reconnect {
    my ( $self, $host, $port, $user ) = @_;
    my $search_local_proxy = {
        user => $user,
        host => $host,
        port => $port
    };
    my $temp_directory = File::Spec->tmpdir();
    my $temp_handle    = DirHandle->new($temp_directory)
      or Firefox::Marionette::Exception->throw(
        "Failed to open directory '$temp_directory':$EXTENDED_OS_ERROR");
  POSSIBLE_REMOTE_PROXY:
    while ( my $tainted_entry = $temp_handle->read() ) {
        next if ( $tainted_entry eq File::Spec->curdir() );
        next if ( $tainted_entry eq File::Spec->updir() );
        if ( $tainted_entry =~ /^($proxy_name_regex)$/smx ) {
            my ($untainted_entry) = ($1);
            my $ssh_local_directory =
              File::Spec->catfile( $temp_directory, $untainted_entry );
            if (
                my $proxy = $self->_matching_remote_proxy(
                    $ssh_local_directory, $search_local_proxy
                )
              )
            {
                $self->{_ssh} = {
                    port => $port,
                    host => $host,
                    user => $user,
                    pid  => $proxy->{ssh}->{pid},
                };
                if (   ( defined $proxy->{firefox} )
                    && ( defined $proxy->{firefox}->{pid} ) )
                {
                    $self->{_firefox_pid} = $proxy->{firefox}->{pid};
                }
                if (   ( defined $proxy->{xvfb} )
                    && ( defined $proxy->{xvfb}->{pid} ) )
                {
                    $self->{_xvfb_pid} = $proxy->{xvfb}->{pid};
                }
                if ( ( $OSNAME eq 'MSWin32' ) || ( $OSNAME eq 'cygwin' ) ) {
                    $self->{_ssh}->{use_control_path} = 0;
                    $self->{_ssh}->{use_unix_sockets} = 0;
                }
                else {
                    $self->{_ssh}->{use_control_path} = 1;
                    $self->{_ssh}->{use_unix_sockets} = 1;
                    $self->{_ssh}->{control_path} =
                      File::Spec->catfile( $ssh_local_directory,
                        'control.sock' );
                }
                $self->{_remote_uname}    = $proxy->{ssh}->{uname};
                $self->{firefox_binary}   = $proxy->{ssh}->{binary};
                $self->{_initial_version} = $proxy->{firefox}->{version};
                $self->_initialise_version();
                $self->{_ssh_local_directory} = $ssh_local_directory;
                $self->{_root_directory}      = $proxy->{ssh}->{root};
                if ( defined $proxy->{ssh}->{tmp} ) {
                    $self->{_original_remote_tmp_directory} =
                      $proxy->{ssh}->{tmp};
                }
                $self->{profile_path} =
                  $self->_remote_catfile( $self->{_root_directory},
                    'profile', 'prefs.js' );
                my $local_scp_directory =
                  File::Spec->catdir( $self->{_ssh_local_directory}, 'scp' );
                $self->{_local_scp_get_directory} =
                  File::Spec->catdir( $local_scp_directory, 'get' );
                $self->{_scp_get_file_index} =
                  $self->_get_max_scp_file_index(
                    $self->{_local_scp_get_directory} );

                $self->{_local_scp_put_directory} =
                  File::Spec->catdir( $local_scp_directory, 'put' );
                $self->{_scp_put_file_index} =
                  $self->_get_max_scp_file_index(
                    $self->{_local_scp_put_directory} );
                last POSSIBLE_REMOTE_PROXY;
            }
        }
    }
    $temp_handle->close()
      or Firefox::Marionette::Exception->throw(
        "Failed to close directory '$temp_directory':$EXTENDED_OS_ERROR");
    if ( $self->_ssh() ) {
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to detect existing local ssh tunnel to $user\@$host");
    }
    return;
}

sub _setup_ssh {
    my ( $self, $host, $port, $user, $reconnect ) = @_;
    if ($reconnect) {
        $self->_setup_ssh_with_reconnect( $host, $port, $user );
    }
    else {
        $self->{_ssh_local_directory} = File::Temp->newdir(
            File::Spec->catdir( File::Spec->tmpdir(), 'perl_ff_m_XXXXXXXXXXX' )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to create temporary directory:$EXTENDED_OS_ERROR");
        my $local_scp_directory =
          File::Spec->catdir( $self->{_ssh_local_directory}, 'scp' );
        mkdir $local_scp_directory, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
            "Failed to create directory $local_scp_directory:$EXTENDED_OS_ERROR"
          );
        $self->{_local_scp_get_directory} =
          File::Spec->catdir( $local_scp_directory, 'get' );
        mkdir $self->{_local_scp_get_directory}, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
"Failed to create directory $self->{_local_scp_get_directory}:$EXTENDED_OS_ERROR"
          );
        $self->{_local_scp_put_directory} =
          File::Spec->catdir( $local_scp_directory, 'put' );
        mkdir $self->{_local_scp_put_directory}, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
"Failed to create directory $self->{_local_scp_put_directory}:$EXTENDED_OS_ERROR"
          );
        $self->{_ssh} = {
            host => $host,
            port => $port,
            user => $user,
        };

        if ( ( $OSNAME eq 'MSWin32' ) || ( $OSNAME eq 'cygwin' ) ) {
            $self->{_ssh}->{use_control_path} = 0;
        }
        else {
            $self->{_ssh}->{use_control_path} = 1;
            $self->{_ssh}->{control_path} =
              File::Spec->catfile( $self->{_ssh_local_directory}->dirname(),
                'control.sock' );
        }
    }
    $self->_initialise_remote_uname();
    return;
}

sub _control_path {
    my ($self) = @_;
    if ( my $ssh = $self->_ssh() ) {
        if ( $ssh->{use_control_path} ) {
            return $ssh->{control_path};
        }
    }
    return;
}

sub _ssh {
    my ($self) = @_;
    return $self->{_ssh};
}

sub _adb {
    my ($self) = @_;
    return $self->{_adb};
}

sub _init {
    my ( $class, %parameters ) = @_;
    my $self = bless {}, $class;
    $self->{last_message_id}  = 0;
    $self->{creation_pid}     = $PROCESS_ID;
    $self->{sleep_time_in_ms} = $parameters{sleep_time_in_ms};
    foreach my $type (qw(nightly developer waterfox)) {
        if ( defined $parameters{$type} ) {
            $self->{requested_version}->{$type} = $parameters{$type};
        }
    }
    if ( defined $parameters{survive} ) {
        $self->{survive} = $parameters{survive};
    }
    $self->{extension_index} = 0;
    $self->{debug}           = $parameters{debug};

    if ( $parameters{firefox_binary} ) {
        Carp::carp(
            '**** DEPRECATED - firefox_binary HAS BEEN REPLACED BY firefox ****'
        );
        $self->{firefox_binary} = $parameters{firefox_binary};
    }
    elsif ( $parameters{firefox} ) {
        $self->{firefox_binary} = $parameters{firefox};
    }

    if ( defined $parameters{adb} ) {
        $self->_setup_adb( $parameters{adb} );
    }
    if ( defined $parameters{host} ) {
        if ( $OSNAME eq 'MSWin32' ) {
            $parameters{user} ||= Win32::LoginName();
        }
        else {
            $parameters{user} ||= getpwuid $EFFECTIVE_USER_ID;
        }
        $parameters{port} ||= scalar getservbyname 'ssh', 'tcp';
        $self->_setup_ssh(
            $parameters{host}, $parameters{port},
            $parameters{user}, $parameters{reconnect}
        );
    }
    if ( defined $parameters{width} ) {
        $self->{window_width} = $parameters{width};
    }
    if ( defined $parameters{height} ) {
        $self->{window_height} = $parameters{height};
    }
    if ( defined $parameters{har} ) {
        $self->{_har} = $parameters{har};
        require Firefox::Marionette::Extension::HarExportTrigger;
    }
    $self->{mime_types} = [
        qw(
          application/x-gzip
          application/gzip
          application/zip
          application/pdf
          application/octet-stream
          application/msword
          application/vnd.openxmlformats-officedocument.wordprocessingml.document
          application/vnd.openxmlformats-officedocument.wordprocessingml.template
          application/vnd.ms-word.document.macroEnabled.12
          application/vnd.ms-word.template.macroEnabled.12
          application/vnd.ms-excel
          application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
          application/vnd.openxmlformats-officedocument.spreadsheetml.template
          application/vnd.ms-excel.sheet.macroEnabled.12
          application/vnd.ms-excel.template.macroEnabled.12
          application/vnd.ms-excel.addin.macroEnabled.12
          application/vnd.ms-excel.sheet.binary.macroEnabled.12
          application/vnd.ms-powerpoint
          application/vnd.openxmlformats-officedocument.presentationml.presentation
          application/vnd.openxmlformats-officedocument.presentationml.template
          application/vnd.openxmlformats-officedocument.presentationml.slideshow
          application/vnd.ms-powerpoint.addin.macroEnabled.12
          application/vnd.ms-powerpoint.presentation.macroEnabled.12
          application/vnd.ms-powerpoint.template.macroEnabled.12
          application/vnd.ms-powerpoint.slideshow.macroEnabled.12
          application/vnd.ms-access
          )
    ];
    my %known_mime_types;
    foreach my $mime_type ( @{ $self->{mime_types} } ) {
        $known_mime_types{$mime_type} = 1;
    }
    foreach my $mime_type ( @{ $parameters{mime_types} } ) {
        if ( !$known_mime_types{$mime_type} ) {
            push @{ $self->{mime_types} }, $mime_type;
            $known_mime_types{$mime_type} = 1;
        }
    }
    return $self;
}

sub _check_for_existing_local_firefox_process {
    my ($self) = @_;
    my $profile_path =
      File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
    my $profile_handle = FileHandle->new($profile_path);
    my $port;
    if ($profile_handle) {
        while ( my $line = <$profile_handle> ) {
            if ( $line =~ /^user_pref[(]"marionette[.]port",[ ](\d+)[)];$/smx )
            {
                ($port) = ($1);
            }
        }
    }
    return $port;
}

sub _reconnected {
    my ($self) = @_;
    return $self->{_reconnected};
}

sub _check_reconnecting_firefox_process_is_alive {
    my ( $self, $pid ) = @_;
    if ( $OSNAME eq 'MSWin32' ) {
        if (
            Win32::Process::Open(
                my $process, $pid, _WIN32_PROCESS_INHERIT_FLAGS()
            )
          )
        {
            $self->{_win32_firefox_process} = $process;
            return $pid;
        }
    }
    elsif ( kill 0, $pid ) {
        return $pid;
    }
    return;
}

sub _get_local_reconnect_pid {
    my ($self)         = @_;
    my $temp_directory = File::Spec->tmpdir();
    my $temp_handle    = DirHandle->new($temp_directory)
      or Firefox::Marionette::Exception->throw(
        "Failed to open directory '$temp_directory':$EXTENDED_OS_ERROR");
    my $alive_pid;
  TEMP_DIR_LISTING: while ( my $tainted_entry = $temp_handle->read() ) {
        next if ( $tainted_entry eq File::Spec->curdir() );
        next if ( $tainted_entry eq File::Spec->updir() );
        if ( $tainted_entry =~ /^($local_name_regex)$/smx ) {
            my ($untainted_entry) = ($1);
            my $possible_root_directory =
              File::Spec->catfile( $temp_directory, $untainted_entry );
            my $local_proxy = $self->_read_possible_proxy_path(
                File::Spec->catfile( $possible_root_directory, 'reconnect' ) );
            if (   ( defined $local_proxy->{firefox} )
                && ( defined $local_proxy->{firefox}->{binary} ) )
            {
                if ( $self->_binary() ne $local_proxy->{firefox}->{binary} ) {
                    next TEMP_DIR_LISTING;
                }
            }
            elsif ( $self->_binary() ) {
                next TEMP_DIR_LISTING;
            }
            if (   ( defined $local_proxy->{firefox} )
                && ( $local_proxy->{firefox}->{pid} ) )
            {
                if (
                    my $check_pid =
                    $self->_check_reconnecting_firefox_process_is_alive(
                        $local_proxy->{firefox}->{pid}
                    )
                  )
                {
                    $alive_pid = $check_pid;
                }
                else {
                    next TEMP_DIR_LISTING;
                }
            }
            else {
                next TEMP_DIR_LISTING;
            }
            if (   ( defined $local_proxy->{xvfb} )
                && ( defined $local_proxy->{xvfb}->{pid} )
                && ( kill 0, $local_proxy->{xvfb}->{pid} ) )
            {
                $self->{_xvfb_pid} = $local_proxy->{xvfb}->{pid};
            }
            $self->{_initial_version} = $local_proxy->{firefox}->{version};
            $self->{_root_directory}  = $possible_root_directory;
            $self->{_profile_directory} =
              File::Spec->catfile( $self->{_root_directory}, 'profile' );
            $self->{_download_directory} =
              File::Spec->catfile( $self->{_root_directory}, 'downloads' );
            $self->{profile_path} =
              File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
        }
    }
    $temp_handle->close();
    return $alive_pid;
}

sub _reconnect {
    my ( $self, %parameters ) = @_;
    $self->{_reconnected} = 1;
    if ( my $ssh = $self->_ssh() ) {
        if ( my $pid = $self->_firefox_pid() ) {
            if ( $self->_remote_process_running($pid) ) {
                $self->{_firefox_pid} = $pid;
            }
        }
    }
    else {
        if ( my $pid = $self->_get_local_reconnect_pid() ) {
            if (
                ( kill 0, $pid )
                && ( my $port =
                    $self->_check_for_existing_local_firefox_process() )
              )
            {
                $self->{_firefox_pid} = $pid;
            }

        }
    }
    my ( $host, $user );
    if ( my $ssh = $self->_ssh() ) {
        $host = $self->_ssh()->{host};
        $user = $self->_ssh()->{user};
    }
    elsif (( $OSNAME eq 'MSWin32' )
        || ( $OSNAME eq 'cygwin' ) )
    {
        $user = Win32::LoginName();
        $host = 'localhost';
    }
    else {
        $user = getpwuid $EFFECTIVE_USER_ID;
        $host = 'localhost';
    }
    my $quoted_user = defined $user ? quotemeta $user : q[];
    if ( $self->_ssh() ) {
        $self->_initialise_remote_uname();
    }
    $self->_check_visible(%parameters);
    my $port = $self->_get_marionette_port();
    defined $port
      or Firefox::Marionette::Exception->throw(
        "Existing firefox process could not be found at $user\@$host");
    my $socket;
    socket $socket,
      $self->_using_unix_sockets_for_ssh_connection()
      ? Socket::PF_UNIX()
      : Socket::PF_INET(), Socket::SOCK_STREAM(), 0
      or Firefox::Marionette::Exception->throw(
        "Failed to create a socket:$EXTENDED_OS_ERROR");
    binmode $socket;
    my $sock_addr = $self->_get_sock_addr( $host, $port );
    connect $socket, $sock_addr
      or Firefox::Marionette::Exception->throw(
        "Failed to connect to remote Firefox process:$EXTENDED_OS_ERROR");
    $self->{_socket} = $socket;
    my $initial_response = $self->_read_from_socket();
    $self->{marionette_protocol} = $initial_response->{marionetteProtocol};
    $self->{application_type}    = $initial_response->{applicationType};

    $self->_compatibility_checks_for_older_marionette();
    return $self->new_session( $parameters{capabilities} );
}

sub _compatibility_checks_for_older_marionette {
    my ($self) = @_;
    if ( !$self->marionette_protocol() ) {
        if ( $self->{_initial_packet_size} == _OLD_INITIAL_PACKET_SIZE() ) {
            $self->{_old_protocols_key} = 'type';
        }
        else {
            $self->{_old_protocols_key} = 'name';
        }
        my $message_id = $self->_new_message_id();
        $self->_send_request(
            [
                _COMMAND(), $message_id, 'getMarionetteID', 'to' => 'root'
            ]
        );
        my $next_message = $self->_read_from_socket();
        $self->{marionette_id} = $next_message->{id};
    }
    return;
}

sub new {
    my ( $class, %parameters ) = @_;
    my $self = $class->_init(%parameters);
    my @arguments;
    my ( $session_id, $capabilities );
    if ( $parameters{reconnect} ) {

        ( $session_id, $capabilities ) = $self->_reconnect(%parameters);
    }
    else {
        @arguments = $self->_setup_arguments(%parameters);
        $self->_launch(@arguments);
        my $socket = $self->_setup_local_connection_to_firefox(@arguments);
        ( $session_id, $capabilities ) =
          $self->_initial_socket_setup( $socket, $parameters{capabilities} );
    }

    if ( ($session_id) && ($capabilities) && ( ref $capabilities ) ) {
    }
    elsif (( $self->marionette_protocol() <= _MARIONETTE_PROTOCOL_VERSION_3() )
        && ($capabilities)
        && ( ref $capabilities ) )
    {
    }
    else {
        Firefox::Marionette::Exception->throw(
            'Failed to correctly setup the Firefox process');
    }
    if ( $self->marionette_protocol() < _MARIONETTE_PROTOCOL_VERSION_3() ) {
    }
    else {
        $self->_check_initial_firefox_pid($capabilities);
    }
    $self->_write_local_proxy( $self->_ssh() );
    $self->_check_timeout_parameters(%parameters);
    if ( $self->{_har} ) {
        $self->_build_local_extension_directory();
        my $path = File::Spec->catfile(
            $self->{_local_extension_directory},
            'har_export_trigger-0.6.1-an+fx.xpi'
        );
        my $handle = FileHandle->new(
            $path,
            Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
            Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to open '$path' for writing:$EXTENDED_OS_ERROR");
        binmode $handle;
        $handle->print(
            MIME::Base64::decode_base64(
                Firefox::Marionette::Extension::HarExportTrigger->as_string()
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to write to '$path':$EXTENDED_OS_ERROR");
        $handle->close()
          or Firefox::Marionette::Exception->throw(
            "Failed to close '$path':$EXTENDED_OS_ERROR");
        $self->install( $path, 0 );
    }
    return $self;
}

sub _check_initial_firefox_pid {
    my ( $self, $capabilities ) = @_;
    my $firefox_pid = $capabilities->moz_process_id();
    if ( $self->_ssh() ) {
    }
    elsif ( ( $OSNAME eq 'cygwin' ) || ( $OSNAME eq 'MSWin32' ) ) {
    }
    elsif ( defined $firefox_pid ) {
        if ( $self->_firefox_pid() != $firefox_pid ) {
            Firefox::Marionette::Exception->throw(
'Failed to correctly determine the Firefox process id through the initial connection capabilities'
            );
        }
    }
    if ( defined $firefox_pid ) {
        $self->{_firefox_pid} = $firefox_pid;
    }
    return;
}

sub _build_local_extension_directory {
    my ($self) = @_;
    if ( !$self->{_local_extension_directory} ) {
        my $root_directory;
        if ( $self->_ssh() ) {
            $root_directory = $self->{_ssh_local_directory};
        }
        else {
            $root_directory = $self->_root_directory();
        }
        $self->{_local_extension_directory} =
          File::Spec->catdir( $root_directory, 'extension' );
        mkdir $self->{_local_extension_directory}, Fcntl::S_IRWXU()
          or ( $OS_ERROR == POSIX::EEXIST() )
          or Firefox::Marionette::Exception->throw(
"Failed to create directory $self->{_local_extension_directory}:$EXTENDED_OS_ERROR"
          );
    }
    return;
}

sub _clean_local_extension_directory {
    my ($self) = @_;
    if ( $self->{_local_extension_directory} ) {

        # manual clearing of the directory to aid with win32 idiocy
        my $handle = DirHandle->new( $self->{_local_extension_directory} )
          or Firefox::Marionette::Exception->throw(
"Failed to open directory '$self->{_local_extension_directory}':$EXTENDED_OS_ERROR"
          );
        my $cleaned = 1;
        while ( my $entry = $handle->read() ) {
            next if ( $entry eq File::Spec->updir() );
            next if ( $entry eq File::Spec->curdir() );
            my $path = File::Spec->catfile( $self->{_local_extension_directory},
                $entry );
            unlink $path or $cleaned = 0;
        }
        $handle->close()
          or Firefox::Marionette::Exception->throw(
"Failed to close directory '$self->{_local_extension_directory}':$EXTENDED_OS_ERROR"
          );
        if ($cleaned) {
            delete $self->{_local_extension_directory};
        }
    }
    return;
}

sub har {
    my ($self)  = @_;
    my $context = $self->context('content');
    my $log     = $self->script(
        'return (async function() { return await HAR.triggerExport() })();');
    $self->context($context);
    return { log => $log };
}

sub _check_timeout_parameters {
    my ( $self, %parameters ) = @_;
    if (   ( defined $parameters{implicit} )
        || ( defined $parameters{page_load} )
        || ( defined $parameters{script} ) )
    {
        my $page_load =
          defined $parameters{page_load}
          ? $parameters{page_load}
          : _DEFAULT_PAGE_LOAD_TIMEOUT();
        my $script =
          defined $parameters{script}
          ? $parameters{script}
          : _DEFAULT_SCRIPT_TIMEOUT();
        my $implicit =
          defined $parameters{implicit}
          ? $parameters{implicit}
          : _DEFAULT_IMPLICIT_TIMEOUT();
        $self->timeouts(
            Firefox::Marionette::Timeouts->new(
                page_load => $page_load,
                script    => $script,
                implicit  => $implicit,
            )
        );
    }
    elsif ( $parameters{timeouts} ) {
        $self->timeouts( $parameters{timeouts} );
    }
    return;
}

sub _check_addons {
    my ( $self, %parameters ) = @_;
    $self->{addons} = 1;
    my @arguments = ();
    if ( $self->{_har} ) {
    }
    elsif ( $parameters{nightly} )
    {    # safe-mode will disable loading extensions in nightly
    }
    elsif ( !$parameters{addons} ) {
        if ( $self->_is_safe_mode_okay() ) {
            push @arguments, '-safe-mode';
            $self->{addons} = 0;
        }
    }
    return @arguments;
}

sub _check_visible {
    my ( $self, %parameters ) = @_;
    my @arguments = ();
    if (   ( defined $parameters{capabilities} )
        && ( defined $parameters{capabilities}->moz_headless() )
        && ( !$parameters{capabilities}->moz_headless() ) )
    {
        if ( !$parameters{visible} ) {
            Carp::carp('Unable to launch firefox with -headless option');
        }
        $self->{visible} = 1;
    }
    elsif ( $parameters{visible} ) {
        $self->{visible} = 1;
    }
    else {
        if ( $self->_is_headless_okay() ) {
            push @arguments, '-headless';
            $self->{visible} = 0;
        }
        elsif (( $OSNAME eq 'MSWin32' )
            || ( $OSNAME eq 'darwin' )
            || ( $OSNAME eq 'cygwin' )
            || ( $self->_ssh() ) )
        {
        }
        else {
            if (   $self->_is_xvfb_okay()
                && $self->_xvfb_exists()
                && $self->_launch_xvfb_if_not_present() )
            {
                $self->{_launched_xvfb_anyway} = 1;
                $self->{visible}               = 0;
            }
            else {
                Carp::carp('Unable to launch firefox with -headless option');
                $self->{visible} = 1;
            }
        }
    }
    $self->_launch_xvfb_if_required();
    return @arguments;
}

sub _launch_xvfb_if_required {
    my ($self) = @_;
    if ( $self->{visible} ) {
        if (   ( $OSNAME eq 'MSWin32' )
            || ( $OSNAME eq 'darwin' )
            || ( $OSNAME eq 'cygwin' )
            || ( $self->_ssh() )
            || ( $ENV{DISPLAY} )
            || ( $self->{_launched_xvfb_anyway} ) )
        {
        }
        elsif ( $self->_xvfb_exists() && $self->_launch_xvfb_if_not_present() )
        {
            $self->{_launched_xvfb_anyway} = 1;
        }
    }
    return;
}

sub _setup_arguments {
    my ( $self, %parameters ) = @_;
    my @arguments = qw(-marionette);

    if ( defined $self->{window_width} ) {
        push @arguments, '-width', $self->{window_width};
    }
    if ( defined $self->{window_height} ) {
        push @arguments, '-height', $self->{window_height};
    }
    push @arguments, $self->_check_addons(%parameters);
    push @arguments, $self->_check_visible(%parameters);
    if ( $parameters{profile_name} ) {
        $self->{profile_name} = $parameters{profile_name};
        push @arguments, ( '-P', $self->{profile_name} );
    }
    else {
        my $profile_directory =
          $self->_setup_new_profile( $parameters{profile}, %parameters );
        if ( $self->_ssh() ) {
            if ( $self->_remote_uname() eq 'cygwin' ) {
                $profile_directory =
                  $self->_execute_via_ssh( {}, 'cygpath', '-s', '-m',
                    $profile_directory );
                chomp $profile_directory;
            }
        }
        elsif ( $OSNAME eq 'cygwin' ) {
            $profile_directory =
              $self->execute( 'cygpath', '-s', '-m', $profile_directory );
        }
        my $mime_types_content = <<'_RDF_';
<?xml version="1.0"?>
<RDF:RDF xmlns:NC="http://home.netscape.com/NC-rdf#"
         xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <RDF:Seq RDF:about="urn:mimetypes:root">
_RDF_
        foreach my $mime_type ( @{ $self->{mime_types} } ) {
            $mime_types_content .= <<'_RDF_';
    <RDF:li RDF:resource="urn:mimetype:$mime_type"/>
_RDF_
        }
        $mime_types_content .= <<'_RDF_';
  </RDF:Seq>
  <RDF:Description RDF:about="urn:root"
                   NC:en-US_defaultHandlersVersion="4" />
  <RDF:Description RDF:about="urn:mimetypes">
    <NC:MIME-types RDF:resource="urn:mimetypes:root"/>
  </RDF:Description>
_RDF_
        foreach my $mime_type ( @{ $self->{mime_types} } ) {
            $mime_types_content .= <<'_RDF_';
  <RDF:Description RDF:about="urn:mimetype:handler:$mime_type"
                   NC:saveToDisk="true"
                   NC:alwaysAsk="false" />
  <RDF:Description RDF:about="urn:mimetype:$mime_type"
                   NC:value="$mime_type">
    <NC:handlerProp RDF:resource="urn:mimetype:handler:$mime_type"/>
  </RDF:Description>
_RDF_
        }
        $mime_types_content .= <<'_RDF_';
</RDF:RDF>
_RDF_
        if ( $self->_ssh() ) {
            $self->_write_mime_types_via_ssh($mime_types_content);
        }
        else {
            my $path =
              File::Spec->catfile( $profile_directory, 'mimeTypes.rdf' );
            my $handle = FileHandle->new(
                $path,
                Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
                Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
              )
              or Firefox::Marionette::Exception->throw(
                "Failed to open '$path' for writing:$EXTENDED_OS_ERROR");
            $handle->print($mime_types_content)
              or Firefox::Marionette::Exception->throw(
                "Failed to write to '$path':$EXTENDED_OS_ERROR");
            $handle->close
              or Firefox::Marionette::Exception->throw(
                "Failed to close '$path':$EXTENDED_OS_ERROR");
        }
        push @arguments,
          ( '-profile', $profile_directory, '--no-remote', '--new-instance' );
        if ( $self->{_har} ) {
            push @arguments, '--devtools';
        }
        if ( $parameters{trust} ) {
            $self->_add_certificates( $profile_directory, %parameters );
        }
    }
    return @arguments;
}

sub _add_certificates {
    my ( $self, $profile_directory, %parameters ) = @_;
    my @paths;
    if ( ref $parameters{trust} ) {
        @paths = @{ $parameters{trust} };
    }
    else {
        @paths = ( $parameters{trust} );
    }
    $self->{_trust_count} ||= 0;
    foreach my $path (@paths) {
        $self->{_trust_count} += 1;
        if ( $self->_ssh() ) {
            $self->{_cert_directory} = $self->_make_remote_directory(
                $self->_remote_catfile( $self->{_root_directory}, 'certs' ) );
            my $remote_path = $self->_remote_catfile( $self->{_cert_directory},
                'root_ca_' . $self->{_trust_count} . '.cer' );
            my $handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
              or Firefox::Marionette::Exception->throw(
                "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
            $self->_put_file_via_scp( $handle, $remote_path, $path );
            $path = $remote_path;
        }
        foreach my $type (qw(dbm sql)) {
            my $binary    = 'certutil';
            my @arguments = (
                '-A',
                '-d' => $type . q[:] . $profile_directory,
                '-i' => $path,
                '-n' => 'Firefox::Marionette Root CA ' . $self->{_trust_count},
                '-t' => 'TC,,',
            );
            $self->execute( $binary, @arguments );
        }
    }
    return;
}

sub _write_mime_types_via_ssh {
    my ( $self, $mime_types_content ) = @_;
    my $handle = File::Temp::tempfile(
        File::Spec->catfile(
            File::Spec->tmpdir(),
            'firefox_marionette_mime_type_data_XXXXXXXXXXX'
        )
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    print {$handle} $mime_types_content
      or Firefox::Marionette::Exception->throw(
        "Failed to write to temporary file:$EXTENDED_OS_ERROR");
    seek $handle, 0, Fcntl::SEEK_SET()
      or Firefox::Marionette::Exception->throw(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    $self->_put_file_via_scp(
        $handle,
        $self->_remote_catfile( $self->{_profile_directory}, 'mimeTypes.rdf' ),
        'mime type data'
    );
    return;
}

sub _is_firefox_major_version_at_least {
    my ( $self, $minimum_version ) = @_;
    $self->_initialise_version();
    if (   ( defined $self->{_initial_version} )
        && ( $self->{_initial_version}->{major} )
        && ( $self->{_initial_version}->{major} >= $minimum_version ) )
    {
        return 1;
    }
    elsif ( defined $self->{_initial_version} ) {
        return 0;
    }
    else {
        return 1;    # assume modern non-firefox branded browser
    }
}

sub _is_xvfb_okay {
    my ($self) = @_;
    if ( $self->_is_firefox_major_version_at_least( _MIN_VERSION_FOR_XVFB() ) )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_new_hostport_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_HOSTPORT_PROXY()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_new_sendkeys_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_NEW_SENDKEYS()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_safe_mode_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_SAFE_MODE()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_headless_okay {
    my ($self) = @_;
    my $min_version = _MIN_VERSION_FOR_HEADLESS();
    if ( ( $OSNAME eq 'MSWin32' ) || ( $OSNAME eq 'darwin' ) ) {
        $min_version = _MIN_VERSION_FOR_WD_HEADLESS();
    }
    if ( $self->_is_firefox_major_version_at_least($min_version) ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_auto_listen_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_AUTO_LISTEN()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub execute {
    my ( $self, $binary, @arguments ) = @_;
    if ( my $ssh = $self->_ssh() ) {
        my $parameters = {};
        if ( !defined $ssh->{ssh_connections_to_host} ) {
            $parameters->{accept_new} = 1;
        }
        if ( !$ssh->{control_established} ) {
            $parameters->{master} = 1;
        }
        if ( !defined $ssh->{first_ssh_connection_to_host} ) {
            $ssh->{ssh_connections_to_host} = 1;
        }
        else {
            $ssh->{ssh_connections_to_host} += 1;
        }
        my $return_code =
          $self->_execute_via_ssh( $parameters, $binary, @arguments );
        if ( ($return_code) && ( $ssh->{use_control_path} ) ) {
            $ssh->{control_established} = 1;
        }
        return $return_code;
    }
    else {
        if ( $self->_debug() ) {
            warn q[** ] . ( join q[ ], $binary, @arguments ) . "\n";
        }
        my ( $writer, $reader, $error );
        my $pid;
        eval {
            $pid =
              IPC::Open3::open3( $writer, $reader, $error, $binary,
                @arguments );
        } or do {
            Firefox::Marionette::Exception->throw(
                "Failed to execute '$binary':$EXTENDED_OS_ERROR");
        };
        my ( $result, $output );
        while ( $result = read $reader, my $buffer,
            _READ_LENGTH_OF_OPEN3_OUTPUT() )
        {
            $output .= $buffer;
        }
        defined $result
          or
          Firefox::Marionette::Exception->throw( q[Failed to read STDOUT from ']
              . ( join q[ ], $binary, @arguments )
              . "':$EXTENDED_OS_ERROR" );
        if ( defined $output ) {
            chomp $output;
            $output =~ s/\r$//smx;
        }
        waitpid $pid, 0;
        if ( $CHILD_ERROR == 0 ) {
            return $output;
        }
        else {
            Firefox::Marionette::Exception->throw( q[Failed to execute ']
                  . ( join q[ ], $binary, @arguments ) . q[':]
                  . $self->_error_message( $binary, $CHILD_ERROR ) );
        }
        return;
    }
}

sub _adb_initialise {
    my ($self) = @_;
    $self->execute( 'adb', 'connect', $self->_adb()->{host} );
    my $adb_regex = qr/package:(.*(firefox|fennec).*)/smx;
    my $binary    = 'adb';
    my @arguments = qw(shell pm list packages);
    my $package_name;
    foreach my $line ( split /\r?\n/smx, $self->execute( $binary, @arguments ) )
    {
        if ( $line =~ /^$adb_regex$/smx ) {
            $package_name = $1;
        }
    }
    return $package_name;
}

sub _execute_via_ssh {
    my ( $self, $parameters, $binary, @arguments ) = @_;
    my $ssh_binary = 'ssh';
    my @ssh_arguments =
      ( $self->_ssh_parameters( %{$parameters} ), $self->_ssh_address() );
    my $output = $self->_get_local_command_output( $parameters, $ssh_binary,
        @ssh_arguments, $binary, @arguments );
    return $output;
}

sub _search_for_version_in_application_ini {
    my ( $self, $binary ) = @_;
    if ( File::Spec->file_name_is_absolute($binary) ) {
        my ( $volume, $directories ) = File::Spec->splitpath($binary);
        my $application_ini_path =
          File::Spec->catfile( $volume, $directories, 'application.ini' );
        my $application_ini_handle =
          FileHandle->new( $application_ini_path, Fcntl::O_RDONLY() );
        if ($application_ini_handle) {
            my $config =
              Config::INI::Reader->read_handle($application_ini_handle);
            if ( my $app = $config->{App} ) {
                return join q[ ], $app->{Vendor}, $app->{Name}, $app->{Version};
            }
        }
    }
    return;
}

sub _initialise_version {
    my ($self) = @_;
    if ( defined $self->{_initial_version} ) {
    }
    else {
        my $binary = $self->_binary();
        $self->{binary} = $binary;
        my $version_string;
        my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))*/smx;
        if ( $self->_adb() ) {
            my $package_name = $self->_adb_initialise();
            my $dumpsys =
              $self->execute( 'adb', 'shell', 'dumpsys', 'package',
                $package_name );
            my $found;
            foreach my $line ( split /\r?\n/smx, $dumpsys ) {
                if ( $line =~ /^[ ]+versionName=$version_regex\s*$/smx ) {
                    $found                             = 1;
                    $self->{_initial_version}->{major} = $1;
                    $self->{_initial_version}->{minor} = $2;
                    $self->{_initial_version}->{patch} = $3;
                }
            }
            if ( !$found ) {
                Firefox::Marionette::Exception->throw(
"'adb shell dumpsys package $package_name' did not produce output that looks like '^[ ]+versionName=\\d+[.]\\d+([.]\\d+)?\\s*\$':$version_string"
                );
            }
        }
        else {
            if ( $self->_ssh() ) {
                $version_string =
                  $self->execute( q["] . $binary . q["], '--version' );
                $version_string =~ s/\r?\n$//smx;
            }
            else {
                if ( $version_string =
                    $self->_search_for_version_in_application_ini($binary) )
                {
                }
                else {
                    $version_string = $self->execute( $binary, '--version' );
                    $version_string =~ s/\r?\n$//smx;
                }
            }
            my $browser_regex = join q[|],
              qr/Mozilla[ ]Firefox[ ]/smx,
              qr/Moonchild[ ]Productions[ ]Basilisk[ ]/smx;
            qr/Moonchild[ ]Productions[ ]Pale[ ]Moon[ ]/smx;
            if ( $version_string =~
                /(?:${browser_regex})${version_regex}[[:alpha:]]*\s*$/smx )

# not anchoring the start of the regex b/c of issues with
# RHEL6 and dbus crashing with error messages like
# 'Failed to open connection to "session" message bus: /bin/dbus-launch terminated abnormally without any error message'
            {
                $self->{_initial_version}->{major} = $1;
                $self->{_initial_version}->{minor} = $2;
                $self->{_initial_version}->{patch} = $3;
            }
            elsif ( defined $self->{_initial_version} ) {
            }
            elsif ( $version_string =~
                /^Waterfox[ ](Current|Classic)[ ]\d{4}[.]\d{2}[.]\d+[.]1/smx )
            {
                my ($waterfox_branch) = ($1);
                if ( $waterfox_branch eq 'Current' ) {
                    $self->{_initial_version}->{major} =
                      _WATERFOX_CURRENT_VERSION_EQUIV();
                }
                else {
                    $self->{_initial_version}->{major} =
                      _WATERFOX_CLASSIC_VERSION_EQUIV();
                }
            }
            else {
                Carp::carp(
"'$binary --version' did not produce output that could be parsed.  Assuming modern Marionette is available"
                );
            }
        }
        $self->_validate_any_requested_version( $binary, $version_string );
    }
    return;
}

sub _validate_any_requested_version {
    my ( $self, $binary, $version_string ) = @_;
    if ( $self->{requested_version}->{nightly} ) {
        if ( !$self->nightly() ) {
            Firefox::Marionette::Exception->throw(
                "$version_string is not a nightly firefox release");
        }
    }
    elsif ( $self->{requested_version}->{developer} ) {
        if ( !$self->developer() ) {
            Firefox::Marionette::Exception->throw(
                "$version_string is not a developer firefox release");
        }
    }
    elsif ( $self->{requested_version}->{waterfox} ) {
        if ( $self->{binary} !~ /waterfox(?:[.]exe)?$/smx ) {
            Firefox::Marionette::Exception->throw(
                "$binary is not a waterfox binary");
        }
    }
    return;
}

sub _debug {
    my ($self) = @_;
    return $self->{debug};
}

sub _visible {
    my ($self) = @_;
    return $self->{visible};
}

sub _firefox_pid {
    my ($self) = @_;
    return $self->{_firefox_pid};
}

sub _local_ssh_pid {
    my ($self) = @_;
    return $self->{_local_ssh_pid};
}

sub _get_full_short_path_for_win32_binary {
    my ( $self, $binary ) = @_;
    if ( File::Spec->file_name_is_absolute($binary) ) {
        return $binary;
    }
    else {
        foreach my $directory ( split /;/smx, $ENV{Path} ) {
            my $possible_path =
              File::Spec->catfile( $directory, $binary . q[.exe] );
            if ( -e $possible_path ) {
                my $path = Win32::GetShortPathName($possible_path);
                return $path;
            }
        }
    }
    return;
}

sub _firefox_tmp_directory {
    my ($self) = @_;
    my $tmp_directory;
    if ( $self->_ssh() ) {
        $tmp_directory = $self->_remote_firefox_tmp_directory();
    }
    else {
        $tmp_directory = $self->_local_firefox_tmp_directory();
    }
    return $tmp_directory;
}

sub _quoting_for_cmd_exe {
    my (@unquoted_arguments) = @_;
    my @quoted_arguments;
    foreach my $unquoted_argument (@unquoted_arguments) {
        $unquoted_argument =~ s/\\"/\\\\"/smxg;
        $unquoted_argument =~ s/"/""/smxg;
        push @quoted_arguments, q["] . $unquoted_argument . q["];
    }
    return join q[ ], @quoted_arguments;
}

sub _win32_process_create_wrapper {
    my ( $self, $full_path, $command_line ) = @_;
    open STDIN, q[<], File::Spec->devnull()
      or Firefox::Marionette::Exception->throw(
        "Failed to redirect STDIN to nul:$EXTENDED_OS_ERROR");
    open STDOUT, q[>], File::Spec->devnull()
      or Firefox::Marionette::Exception->throw(
        "Failed to redirect STDOUT to nul:$EXTENDED_OS_ERROR");
    local $ENV{TMPDIR} = $self->_firefox_tmp_directory();
    my $result = Win32::Process::Create(
        my $process, $full_path, $command_line,
        _WIN32_PROCESS_INHERIT_FLAGS(),
        Win32::Process::NORMAL_PRIORITY_CLASS(), q[.]
    );
    return ( $process, $result );
}

sub _save_stdin {
    my ($self) = @_;
    open my $local_stdin, q[<&], fileno STDIN
      or Firefox::Marionette::Exception->throw(
        "Failed to save STDIN:$EXTENDED_OS_ERROR");
    return $local_stdin;
}

sub _save_stdout {
    open my $local_stdout, q[>&], fileno STDOUT
      or Firefox::Marionette::Exception->throw(
        "Failed to save STDOUT:$EXTENDED_OS_ERROR");
    return $local_stdout;
}

sub _restore_stdin_stdout {
    my ( $self, $local_stdin, $local_stdout ) = @_;
    open STDIN, q[<&], fileno $local_stdin
      or Firefox::Marionette::Exception->throw(
        "Failed to restore STDIN:$EXTENDED_OS_ERROR");
    close $local_stdin
      or Firefox::Marionette::Exception->throw(
        "Failed to close saved STDIN handle:$EXTENDED_OS_ERROR");
    open STDOUT, q[>&], fileno $local_stdout
      or Firefox::Marionette::Exception->throw(
        "Failed to restore STDOUT:$EXTENDED_OS_ERROR");
    close $local_stdout
      or Firefox::Marionette::Exception->throw(
        "Failed to close saved STDOUT handle:$EXTENDED_OS_ERROR");
    return;
}

sub _start_win32_process {
    my ( $self, $binary, @arguments ) = @_;
    my $full_path    = $self->_get_full_short_path_for_win32_binary($binary);
    my $command_line = _quoting_for_cmd_exe( $binary, @arguments );
    if ( $self->_debug() ) {
        warn q[** ] . $command_line . "\n";
    }
    my $local_stdout = $self->_save_stdout();
    my $local_stdin  = $self->_save_stdin();
    my ( $process, $result ) =
      $self->_win32_process_create_wrapper( $full_path, $command_line );
    $self->_restore_stdin_stdout( $local_stdin, $local_stdout );

    if ( !$result ) {
        my $error = Win32::FormatMessage( Win32::GetLastError() );
        $error =~ s/[\r\n]//smxg;
        $error =~ s/[.]$//smxg;
        chomp $error;
        Firefox::Marionette::Exception->throw(
            "Failed to create process from '$binary':$error");
    }
    return $process;
}

sub _execute_win32_process {
    my ( $self, $binary, @arguments ) = @_;
    my $process = $self->_start_win32_process( $binary, @arguments );
    $process->GetExitCode( my $exit_code );
    while ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
        $process->GetExitCode($exit_code);
    }
    if ( $exit_code == 0 ) {
        return 1;
    }
    else {
        return;
    }
}

sub _launch_via_ssh {
    my ( $self, @arguments ) = @_;
    if ( $OSNAME eq 'MSWin32' ) {
        my $ssh_binary = $self->_get_full_short_path_for_win32_binary('ssh')
          or Firefox::Marionette::Exception->throw(
"Failed to find 'ssh' anywhere in the Path environment variable:$ENV{Path}"
          );
        my @ssh_arguments =
          ( $self->_ssh_parameters( env => 1 ), $self->_ssh_address() );
        my $process =
          $self->_start_win32_process( 'ssh', @ssh_arguments,
            q["] . $self->_binary() . q["], @arguments );
        $self->{_win32_ssh_process} = $process;
        if ( $self->{survive} ) {
            $self->{_ssh_local_directory}->unlink_on_destroy(0);
        }
        my $pid = $process->GetProcessID();
        $self->{_ssh}->{pid} = $pid;
        return $pid;
    }
    else {
        my $dev_null = File::Spec->devnull();

        if ( my $pid = fork ) {
            $self->{_ssh}->{pid} = $pid;
            if ( $self->{survive} ) {
                $self->{_ssh_local_directory}->unlink_on_destroy(0);
            }
            return $pid;
        }
        elsif ( defined $pid ) {
            eval {
                open STDIN, q[<], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDIN to $dev_null:$EXTENDED_OS_ERROR");
                $self->_ssh_exec(
                    $self->_ssh_parameters( env => 1 ), $self->_ssh_address(),
                    q["] . $self->_binary() . q["],     @arguments
                  )
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
            } or do {
                if ( $self->_debug() ) {
                    chomp $EVAL_ERROR;
                    warn "$EVAL_ERROR\n";
                }
            };
            exit 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to fork:$EXTENDED_OS_ERROR");
        }
    }
    return;
}

sub _remote_firefox_tmp_directory {
    my ($self) = @_;
    return $self->{_remote_tmp_directory};
}

sub _local_firefox_tmp_directory {
    my ($self) = @_;
    my $root_directory = $self->_root_directory();
    return File::Spec->catdir( $root_directory, 'tmp' );
}

sub _launch {
    my ( $self, @arguments ) = @_;
    if ( $self->_ssh() ) {
        $self->{_local_ssh_pid} = $self->_launch_via_ssh(@arguments);
        return;
    }
    if ( $self->{survive} ) {
        $self->{_root_directory}->unlink_on_destroy(0);
    }
    if ( $OSNAME eq 'MSWin32' ) {
        local $ENV{TMPDIR} = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_win32(@arguments);
    }
    elsif (( $OSNAME ne 'darwin' )
        && ( $OSNAME ne 'cygwin' )
        && ( $self->_visible() )
        && ( !$ENV{DISPLAY} )
        && ( !$self->{_launched_xvfb_anyway} )
        && ( $self->_xvfb_exists() )
        && ( $self->_launch_xvfb_if_not_present() ) )
    { # if not MacOS or Win32 and no DISPLAY variable, launch Xvfb if at all possible
        local $ENV{DISPLAY}    = $self->_xvfb_display();
        local $ENV{XAUTHORITY} = $self->_xvfb_xauthority();
        local $ENV{TMPDIR}     = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_unix(@arguments);
    }
    elsif ( $self->{_launched_xvfb_anyway} ) {
        local $ENV{DISPLAY}    = $self->_xvfb_display();
        local $ENV{XAUTHORITY} = $self->_xvfb_xauthority();
        local $ENV{TMPDIR}     = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_unix(@arguments);
    }
    else {
        local $ENV{TMPDIR} = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_unix(@arguments);
    }
    return;
}

sub _launch_win32 {
    my ( $self, @arguments ) = @_;
    my $binary  = $self->_binary();
    my $process = $self->_start_win32_process( $binary, @arguments );
    $self->{_win32_firefox_process} = $process;
    return $process->GetProcessID();
}

sub _xvfb_binary {
    return 'Xvfb';
}

sub _dev_fd_works {
    my ($self) = @_;
    my $test_handle =
      File::Temp::tempfile( File::Spec->tmpdir(),
        'firefox_marionette_dev_fd_test_XXXXXXXXXXX' )
      or Firefox::Marionette::Exception->throw(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    my @stats = stat '/dev/fd/' . fileno $test_handle;
    if ( scalar @stats ) {
        return 1;
    }
    elsif ( $OSNAME eq 'freebsd' ) {
        Carp::carp(
q[/dev/fd is not working.  Perhaps you need to mount fdescfs like so 'sudo mount -t fdescfs fdesc /dev/fd']
        );
    }
    else {
        Carp::carp("/dev/fd is not working for $OSNAME");
    }
    return 0;
}

sub _xvfb_exists {
    my ($self)   = @_;
    my $binary   = $self->_xvfb_binary();
    my $dev_null = File::Spec->devnull();
    if ( !$self->_dev_fd_works() ) {
        return 0;
    }
    eval { require Crypt::URandom; } or do {
        Carp::carp('Unable to load Crypt::URandom');
        return 0;
    };
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        if ( $CHILD_ERROR == 0 ) {
            return 1;
        }
    }
    elsif ( defined $pid ) {
        eval {
            open STDERR, q[>], $dev_null
              or Firefox::Marionette::Exception->throw(
                "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR");
            open STDOUT, q[>], $dev_null
              or Firefox::Marionette::Exception->throw(
                "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR");
            exec {$binary} $binary, '-help'
              or Firefox::Marionette::Exception->throw(
                "Failed to exec '$binary':$EXTENDED_OS_ERROR");
        } or do {
            if ( $self->_debug() ) {
                chomp $EVAL_ERROR;
                warn "$EVAL_ERROR\n";
            }
        };
        exit 1;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return;
}

sub xvfb {
    my ($self) = @_;
    return $self->{_xvfb_pid};
}

sub _launch_xauth {
    my ( $self, $display_number ) = @_;
    my $auth_handle = FileHandle->new(
        $ENV{XAUTHORITY},
        Fcntl::O_CREAT() | Fcntl::O_WRONLY() | Fcntl::O_EXCL(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$ENV{XAUTHORITY}' for writing:$EXTENDED_OS_ERROR");
    $auth_handle->close()
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$ENV{XAUTHORITY}':$EXTENDED_OS_ERROR");
    my $mcookie = unpack 'H*',
      Crypt::URandom::urandom( _NUMBER_OF_MCOOKIE_BYTES() );
    my $source_handle =
      File::Temp::tempfile( File::Spec->tmpdir(),
        'firefox_marionette_xauth_source_XXXXXXXXXXX' )
      or Firefox::Marionette::Exception->throw(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    fcntl $source_handle, Fcntl::F_SETFD(), 0
      or Firefox::Marionette::Exception->throw(
"Failed to clear the close-on-exec flag on a temporary file:$EXTENDED_OS_ERROR"
      );
    my $xauth_proto = q[.];
    $source_handle->print("add :$display_number $xauth_proto $mcookie\n");
    seek $source_handle, 0, Fcntl::SEEK_SET()
      or Firefox::Marionette::Exception->throw(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    my $dev_null  = File::Spec->devnull();
    my $binary    = 'xauth';
    my @arguments = ( 'source', '/dev/fd/' . fileno $source_handle );

    if ( my $pid = fork ) {
        waitpid $pid, 0;
        if ( $CHILD_ERROR == 0 ) {
            close $source_handle
              or Firefox::Marionette::Exception->throw(
                "Failed to close temporary file:$EXTENDED_OS_ERROR");
            return 1;
        }
    }
    elsif ( defined $pid ) {
        eval {
            if ( !$self->_debug() ) {
                open STDERR, q[>], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
                open STDOUT, q[>], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            exec {$binary} $binary, @arguments
              or Firefox::Marionette::Exception->throw(
                "Failed to exec '$binary':$EXTENDED_OS_ERROR");
        } or do {
            if ( $self->_debug() ) {
                chomp $EVAL_ERROR;
                warn "$EVAL_ERROR\n";
            }
        };
        exit 1;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return;
}

sub _xvfb_display {
    my ($self) = @_;
    return ":$self->{_xvfb_display_number}";
}

sub _xvfb_xauthority {
    my ($self) = @_;
    return File::Spec->catfile( $self->{_xvfb_authority_directory},
        'Xauthority' );
}

sub _launch_xvfb_if_not_present {
    my ($self) = @_;
    if ( ( $self->{_xvfb_pid} ) && ( kill 0, $self->{_xvfb_pid} ) ) {
        return 1;
    }
    else {
        return $self->_launch_xvfb();
    }
}

sub _launch_xvfb {
    my ($self)         = @_;
    my $root_directory = $self->_root_directory();
    my $xvfb_directory = File::Spec->catdir( $root_directory, 'xvfb' );
    mkdir $xvfb_directory, Fcntl::S_IRWXU()
      or Firefox::Marionette::Exception->throw(
        "Failed to create directory $xvfb_directory:$EXTENDED_OS_ERROR");
    my $fbdir_directory = File::Spec->catdir( $xvfb_directory, 'fbdir' );
    mkdir $fbdir_directory, Fcntl::S_IRWXU()
      or Firefox::Marionette::Exception->throw(
        "Failed to create directory $fbdir_directory:$EXTENDED_OS_ERROR");
    my $display_no_path = File::Spec->catfile( $xvfb_directory, 'display_no' );
    my $display_no_handle = FileHandle->new(
        $display_no_path,
        Fcntl::O_CREAT() | Fcntl::O_RDWR() | Fcntl::O_EXCL(),
        Fcntl::S_IWUSR() | Fcntl::S_IRUSR()
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$display_no_path' for writing:$EXTENDED_OS_ERROR");
    fcntl $display_no_handle, Fcntl::F_SETFD(), 0
      or Firefox::Marionette::Exception->throw(
"Failed to clear the close-on-exec flag on a temporary file:$EXTENDED_OS_ERROR"
      );
    my $width =
      defined $self->{window_width}
      ? $self->{window_width}
      : _DEFAULT_WINDOW_WIDTH();
    my $height =
      defined $self->{window_height}
      ? $self->{window_height}
      : _DEFAULT_WINDOW_HEIGHT();
    my $width_height_depth = join q[x], $width, $height, _DEFAULT_DEPTH();
    my @arguments = (
        '-displayfd' => fileno $display_no_handle,
        '-screen'    => '0',
        $width_height_depth,
        '-nolisten' => 'tcp',
        '-fbdir'    => $fbdir_directory,
    );
    my $binary   = $self->_xvfb_binary();
    my $dev_null = File::Spec->devnull();

    if ( my $pid = fork ) {
        $self->{_xvfb_pid} = $pid;
        my $display_number =
          $self->_wait_for_display_number( $pid, $display_no_handle );
        if ( !defined $display_number ) {
            return;
        }
        $self->{_xvfb_display_number} = $display_number;
        close $display_no_handle
          or Firefox::Marionette::Exception->throw(
            "Failed to close temporary file:$EXTENDED_OS_ERROR");
        $self->{_xvfb_authority_directory} =
          File::Spec->catdir( $xvfb_directory, 'xauth' );
        mkdir $self->{_xvfb_authority_directory}, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
"Failed to create directory $self->{_xvfb_authority_directory}:$EXTENDED_OS_ERROR"
          );
        local $ENV{DISPLAY}    = $self->_xvfb_display();
        local $ENV{XAUTHORITY} = $self->_xvfb_xauthority();
        if ( $self->_launch_xauth($display_number) ) {
            return 1;
        }
    }
    elsif ( defined $pid ) {
        eval {
            if ( !$self->_debug() ) {
                open STDERR, q[>], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
                open STDOUT, q[>], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            exec {$binary} $binary, @arguments
              or Firefox::Marionette::Exception->throw(
                "Failed to exec '$binary':$EXTENDED_OS_ERROR");
        } or do {
            if ( $self->_debug() ) {
                chomp $EVAL_ERROR;
                warn "$EVAL_ERROR\n";
            }
        };
        exit 1;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return;
}

sub _wait_for_display_number {
    my ( $self, $pid, $display_no_handle ) = @_;
    my $display_number = [];
    while ( $display_number !~ /^\d+$/smx ) {
        seek $display_no_handle, 0, Fcntl::SEEK_SET()
          or Firefox::Marionette::Exception->throw(
            "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
        defined sysread $display_no_handle, $display_number,
          _MAX_DISPLAY_LENGTH()
          or Firefox::Marionette::Exception->throw(
            "Failed to read from temporary file:$EXTENDED_OS_ERROR");
        chomp $display_number;
        if ( $display_number !~ /^\d+$/smx ) {
            sleep 1;
        }
        waitpid $pid, POSIX::WNOHANG();
        if ( !kill 0, $pid ) {
            Carp::carp('Xvfb has crashed before sending a display number');
            return;
        }
        else {
            sleep 1;
        }
    }
    return $display_number;
}

sub _launch_unix {
    my ( $self, @arguments ) = @_;
    my $binary = $self->_binary();
    my $pid;
    if ( $self->_debug() ) {
        warn q[** ] . ( join q[ ], $binary, @arguments ) . "\n";
    }
    if ( $OSNAME eq 'cygwin' ) {
        eval {
            $pid =
              IPC::Open3::open3( my $writer, my $reader, my $error, $binary,
                @arguments );
        } or do {
            Firefox::Marionette::Exception->throw(
                "Failed to exec '$binary':$EXTENDED_OS_ERROR");
        };
    }
    else {
        my $dev_null = File::Spec->devnull();
        if ( $pid = fork ) {
        }
        elsif ( defined $pid ) {
            eval {
                if ( !$self->_debug() ) {
                    open STDERR, q[>], $dev_null
                      or Firefox::Marionette::Exception->throw(
"Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                      );
                    open STDOUT, q[>], $dev_null
                      or Firefox::Marionette::Exception->throw(
"Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR"
                      );
                }
                exec {$binary} $binary, @arguments
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec '$binary':$EXTENDED_OS_ERROR");
            } or do {
                if ( $self->_debug() ) {
                    chomp $EVAL_ERROR;
                    warn "$EVAL_ERROR\n";
                }
            };
            exit 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to fork:$EXTENDED_OS_ERROR");
        }
    }
    return $pid;
}

sub _search_paths_for_firefox_on_osx {
    my ($self) = @_;
    if ( $self->{requested_version} ) {
        if ( $self->{requested_version}->{nightly} ) {
            return ( '/Applications/Firefox Nightly.app/Contents/MacOS/firefox',
            );
        }
        if ( $self->{requested_version}->{developer} ) {
            return (
'/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox',
            );
        }
        if ( $self->{requested_version}->{waterfox} ) {
            return (
                '/Applications/Waterfox Current.app/Contents/MacOS/waterfox', );
        }
    }
    return (
        '/Applications/Firefox.app/Contents/MacOS/firefox',
        '/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox',
        '/Applications/Firefox Nightly.app/Contents/MacOS/firefox',
        '/Applications/Waterfox Current.app/Contents/MacOS/waterfox',
    );
}

my %_known_win32_organisations = (
    'Mozilla Firefox'           => 'Mozilla',
    'Mozilla Firefox ESR'       => 'Mozilla',
    'Firefox Developer Edition' => 'Mozilla',
    Nightly                     => 'Mozilla',
    'Waterfox Current'          => 'Waterfox',
    'Waterfox Classic'          => 'Waterfox',
    Basilisk                    => 'Mozilla',
    'Pale Moon'                 => 'Mozilla',
);

sub _win32_organisation {
    my ( $self, $name ) = @_;
    return $_known_win32_organisations{$name};
}

sub _known_win32_preferred_names {
    my ($self) = @_;
    my %known_win32_preferred_names = (
        'Mozilla Firefox'           => 1,
        'Mozilla Firefox ESR'       => 2,
        'Firefox Developer Edition' => 3,
        Nightly                     => 4,
        'Waterfox Current'          => 5,
        Basilisk                    => 6,
        'Pale Moon'                 => 7,
    );
    if ( $self->{requested_version} ) {
        if ( $self->{requested_version}->{nightly} ) {
            foreach
              my $key ( sort { $a cmp $b } keys %known_win32_preferred_names )
            {
                if ( $key ne 'Nightly' ) {
                    delete $known_win32_preferred_names{$key};
                }
            }
        }
        if ( $self->{requested_version}->{developer} ) {
            foreach
              my $key ( sort { $a cmp $b } keys %known_win32_preferred_names )
            {
                if ( $key ne 'Firefox Developer Edition' ) {
                    delete $known_win32_preferred_names{$key};
                }
            }
        }
        if ( $self->{requested_version}->{waterfox} ) {
            foreach
              my $key ( sort { $a cmp $b } keys %known_win32_preferred_names )
            {
                if ( $key ne 'Waterfox Current' ) {
                    delete $known_win32_preferred_names{$key};
                }
            }
        }
    }
    return %known_win32_preferred_names;
}

sub _reg_query_via_ssh {
    my ( $self, %parameters ) = @_;
    my $binary = 'reg';
    my @parameters =
      ( 'query', q["] . ( join q[\\], @{ $parameters{subkey} } ) . q["] );
    if ( $parameters{name} ) {
        push @parameters, ( '/v', q["] . $parameters{name} . q["] );
    }
    my @values;
    my $reg_query = $self->_execute_via_ssh( { ignore_exit_status => 1 },
        $binary, @parameters );
    if ( defined $reg_query ) {

        foreach my $line ( split /\r?\n/smx, $reg_query ) {
            if ( defined $parameters{name} ) {
                my $name =
                  $parameters{name} eq q[] ? '(Default)' : $parameters{name};
                my $quoted_name = quotemeta $name;
                if ( $line =~
                    /^[ ]+${quoted_name}[ ]+(?:REG_SZ)[ ]+(\S.*\S)\s*$/smx )
                {
                    push @values, $1;
                }
            }
            else {
                push @values, $line;
            }
        }
    }
    return @values;
}

sub _cygwin_reg_query_value {
    my ( $self, $path ) = @_;
    my $handle = FileHandle->new( $path, Fcntl::O_RDONLY() );
    my $value;
    if ( defined $handle ) {
        my $result;
        while ( $result =
            $handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() ) )
        {
            $value .= $buffer;
        }
        defined $result
          or Firefox::Marionette::Exception->throw(
            "Failed to read from '$path':$EXTENDED_OS_ERROR");
        $handle->close()
          or Firefox::Marionette::Exception->throw(
            "Failed to close '$path':$EXTENDED_OS_ERROR");
        $value =~ s/\0$//smx;
    }
    elsif ( $EXTENDED_OS_ERROR == POSIX::ENOENT() ) {
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
    }
    return $value;
}

sub _get_firefox_from_cygwin_registry_via_ssh {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->_known_win32_preferred_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE/WOW6432Node)) {
            my $organisation = $self->_win32_organisation($name);
            my $version      = $self->_execute_via_ssh(
                { ignore_exit_status => 1 },
                'cat',
                '"/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name
                  . '/CurrentVersion"'
            );
            if ( !defined $version ) {
                next ROOT_SUBKEY;
            }
            $version =~ s/\0$//smx;
            my $initial_version = $self->_execute_via_ssh( {}, 'cat',
                    '"/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name . q[/@]
                  . q["] );    # (Default) value
            my $name_for_path_to_exe = $name;
            $name_for_path_to_exe =~ s/[ ]ESR//smx;
            my $path = $self->_execute_via_ssh( {}, 'cat',
                    '"/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name_for_path_to_exe . q[/]
                  . $version
                  . '/Main/PathToExe"' );
            my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?/smx;
            if (   ( defined $path )
                && ( $initial_version =~ /^$version_regex$/smx ) )
            {
                $self->{_initial_version}->{major} = $1;
                $self->{_initial_version}->{minor} = $2;
                $self->{_initial_version}->{patch} = $3;
                $path =~ s/\0$//smx;
                $binary = $self->_execute_via_ssh( {}, 'cygpath', '-s', '-m',
                    q["] . $path . q["] );
                chomp $binary;
                last NAME;
            }
        }
    }
    return $binary;
}

sub _get_firefox_from_cygwin_registry {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->_known_win32_preferred_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE/WOW6432Node)) {
            my $organisation = $self->_win32_organisation($name);
            my $version      = $self->_cygwin_reg_query_value(
                    '/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name
                  . '/CurrentVersion' );
            if ( !defined $version ) {
                next ROOT_SUBKEY;
            }
            my $initial_version = $self->_cygwin_reg_query_value(
                    '/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name
                  . q[/@] );    # (Default) value
            my $name_for_path_to_exe = $name;
            $name_for_path_to_exe =~ s/[ ]ESR//smx;
            my $path = $self->_cygwin_reg_query_value(
                    '/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name_for_path_to_exe . q[/]
                  . $version
                  . '/Main/PathToExe' );
            my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?/smx;
            if (   ( defined $path )
                && ( -e $path )
                && ( $initial_version =~ /^$version_regex$/smx ) )
            {
                $self->{_initial_version}->{major} = $1;
                $self->{_initial_version}->{minor} = $2;
                $self->{_initial_version}->{patch} = $3;
                $binary                            = $path;
                last NAME;
            }
        }
    }
    return $binary;
}

sub _get_firefox_from_win32_registry_via_ssh {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->_known_win32_preferred_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey ( ['SOFTWARE'], [ 'SOFTWARE', 'WOW6432Node' ] )
        {
            my $organisation = $self->_win32_organisation($name);
            my ($version) = $self->_reg_query_via_ssh(
                subkey => [ 'HKLM', @{$root_subkey}, $organisation, $name ],
                name   => 'CurrentVersion'
            );
            if ( !defined $version ) {
                next ROOT_SUBKEY;
            }
            my ($initial_version) = $self->_reg_query_via_ssh(
                subkey => [ 'HKLM', @{$root_subkey}, $organisation, $name ],
                name   => q[]    # (Default) value
            );
            my $name_for_path_to_exe = $name;
            $name_for_path_to_exe =~ s/[ ]ESR//smx;
            my ($path) = $self->_reg_query_via_ssh(
                subkey => [
                    'HKLM',        @{$root_subkey},
                    $organisation, $name_for_path_to_exe,
                    $version,      'Main'
                ],
                name => 'PathToExe'
            );
            my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?/smx;
            if (   ( defined $path )
                && ( $initial_version =~ /^$version_regex$/smx ) )
            {
                $self->{_initial_version}->{major} = $1;
                $self->{_initial_version}->{minor} = $2;
                $self->{_initial_version}->{patch} = $3;
                $binary                            = $path;
                last NAME;
            }
        }
    }
    return $binary;
}

sub _win32_registry_query_key {
    my ( $self, $hkey, $subkey, $name ) = @_;
    Win32API::Registry::RegOpenKeyEx( $hkey, $subkey, 0,
        Win32API::Registry::KEY_QUERY_VALUE(),
        my $key )
      or return;
    Win32API::Registry::RegQueryValueEx( $key, $name, [], my $type, my $value,
        [] )
      or return;
    Win32API::Registry::RegCloseKey($key)
      or Firefox::Marionette::Exception->throw(
        "Failed to close registry key $subkey:"
          . Win32API::Registry::regLastError() );
    return $value;
}

sub _get_firefox_from_local_win32_registry {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->_known_win32_preferred_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE\\WOW6432Node)) {
            my $organisation = $self->_win32_organisation($name);
            my $version      = $self->_win32_registry_query_key(
                Win32API::Registry::HKEY_LOCAL_MACHINE(),
                "$root_subkey\\$organisation\\$name",
                'CurrentVersion'
            );
            if ( !defined $version ) {
                next ROOT_SUBKEY;
            }
            my $initial_version = $self->_win32_registry_query_key(
                Win32API::Registry::HKEY_LOCAL_MACHINE(),
                "$root_subkey\\$organisation\\$name", q[] );   # (Default) value
            my $name_for_path_to_exe = $name;
            $name_for_path_to_exe =~ s/[ ]ESR//smx;
            my $path = $self->_win32_registry_query_key(
                Win32API::Registry::HKEY_LOCAL_MACHINE(),
"$root_subkey\\$organisation\\$name_for_path_to_exe\\$version\\Main",
                'PathToExe'
            );
            my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?/smx;
            if (   ( defined $path )
                && ( $initial_version =~ /^$version_regex$/smx ) )
            {
                $self->{_initial_version}->{major} = $1;
                $self->{_initial_version}->{minor} = $2;
                $self->{_initial_version}->{patch} = $3;
                $binary                            = $path;
                last NAME;
            }
        }
    }
    return $binary;
}

sub _get_firefox_from_local_osx_filesystem {
    my ($self) = @_;
    foreach my $path ( $self->_search_paths_for_firefox_on_osx() ) {
        if ( stat $path ) {
            return $path;
        }
    }
    return;
}

sub _get_firefox_from_remote_osx_filesystem {
    my ($self) = @_;
    foreach my $path ( $self->_search_paths_for_firefox_on_osx() ) {
        foreach my $result ( split /\n/smx,
            $self->execute( 'ls', '-1', q["] . $path . q["] ) )
        {
            if ( $result eq $path ) {
                my $plist_path = $path;
                if ( $plist_path =~
                    s/Contents\/MacOS.*$/Contents\/Info.plist/smx )
                {
                    my $plist_json = $self->execute(
                        'plutil', '-convert',
                        'json',   '-o',
                        q[-],     q["] . $plist_path . q["]
                    );
                    my $plist_ref = JSON::decode_json($plist_json);
                    my $version_regex =
                      qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?/smx;
                    if ( $plist_ref->{CFBundleShortVersionString} =~
                        /^$version_regex$/smx )
                    {
                        $self->{_initial_version}->{major} = $1;
                        $self->{_initial_version}->{minor} = $2;
                        $self->{_initial_version}->{patch} = $3;
                        return $path;
                    }
                }
            }
        }
    }
    return;
}

sub _get_remote_binary {
    my ($self) = @_;
    my $binary;
    if ( $self->_remote_uname() eq 'MSWin32' ) {
        if ( !$self->{firefox_binary_from_registry} ) {
            $self->{firefox_binary_from_registry} =
              $self->_get_firefox_from_win32_registry_via_ssh();
        }
        if ( $self->{firefox_binary_from_registry} ) {
            $binary = $self->{firefox_binary_from_registry};
        }
    }
    elsif ( $self->_remote_uname() eq 'darwin' ) {
        if ( !$self->{firefox_binary_from_osx_filesystem} ) {
            $self->{firefox_binary_from_osx_filesystem} =
              $self->_get_firefox_from_remote_osx_filesystem();
        }
        if ( $self->{firefox_binary_from_osx_filesystem} ) {
            $binary = $self->{firefox_binary_from_osx_filesystem};
        }
    }
    elsif ( $self->_remote_uname() eq 'cygwin' ) {
        if ( !$self->{firefox_binary_from_cygwin_registry} ) {
            $self->{firefox_binary_from_cygwin_registry} =
              $self->_get_firefox_from_cygwin_registry_via_ssh();
        }
        if ( $self->{firefox_binary_from_cygwin_registry} ) {
            $binary = $self->{firefox_binary_from_cygwin_registry};
        }
    }
    return $binary;
}

sub _get_local_binary {
    my ($self) = @_;
    my $binary;
    if ( $OSNAME eq 'MSWin32' ) {
        if ( !$self->{firefox_binary_from_registry} ) {
            $self->{firefox_binary_from_registry} =
              $self->_get_firefox_from_local_win32_registry();
        }
        if ( $self->{firefox_binary_from_registry} ) {
            $binary =
              Win32::GetShortPathName( $self->{firefox_binary_from_registry} );
        }
    }
    elsif ( $OSNAME eq 'darwin' ) {
        if ( !$self->{firefox_binary_from_osx_filesystem} ) {
            $self->{firefox_binary_from_osx_filesystem} =
              $self->_get_firefox_from_local_osx_filesystem();
        }
        if ( $self->{firefox_binary_from_osx_filesystem} ) {
            $binary = $self->{firefox_binary_from_osx_filesystem};
        }
    }
    elsif ( $OSNAME eq 'cygwin' ) {
        my $cygwin_binary = $self->_get_firefox_from_cygwin_registry();
        if ( defined $cygwin_binary ) {
            $binary = $self->execute( 'cygpath', '-s', '-m', $cygwin_binary );
        }
    }
    return $binary;
}

sub _binary {
    my ($self) = @_;
    my $binary = 'firefox';
    if ( $self->{firefox_binary} ) {
        $binary = $self->{firefox_binary};
    }
    elsif ( $self->_ssh() ) {
        if ( my $remote_binary = $self->_get_remote_binary() ) {
            $binary = $remote_binary;
        }
    }
    else {
        if ( my $local_binary = $self->_get_local_binary() ) {
            $binary = $local_binary;
        }
    }
    return $binary;
}

sub child_error {
    my ($self) = @_;
    return $self->{_child_error};
}

sub _signal_name {
    my ( $proto, $number ) = @_;
    my @sig_names = split q[ ], $Config{sig_name};
    return $sig_names[$number];
}

sub error_message {
    my ($self) = @_;
    return $self->_error_message( 'Firefox', $self->child_error() );
}

sub _error_message {
    my ( $self, $binary, $child_error ) = @_;
    my $message;
    if ( !defined $child_error ) {
    }
    elsif ( $OSNAME eq 'MSWin32' ) {
        $message = Win32::FormatMessage( Win32::GetLastError() );
    }
    else {

        if (   ( POSIX::WIFEXITED($child_error) )
            || ( POSIX::WIFSIGNALED($child_error) ) )
        {
            if ( POSIX::WIFEXITED($child_error) ) {
                $message =
                    $binary
                  . ' exited with a '
                  . POSIX::WEXITSTATUS($child_error);
            }
            elsif ( POSIX::WIFSIGNALED($child_error) ) {
                my $name = $self->_signal_name( POSIX::WTERMSIG($child_error) );
                if ( defined $name ) {
                    $message = "$binary killed by a $name signal ("
                      . POSIX::WTERMSIG($child_error) . q[)];
                }
                else {
                    $message =
                        $binary
                      . ' killed by a signal ('
                      . POSIX::WTERMSIG($child_error) . q[)];
                }
            }
        }
    }
    return $message;
}

sub _reap {
    my ($self) = @_;
    if ( $OSNAME eq 'MSWin32' ) {
        if ( $self->{_win32_firefox_process} ) {
            $self->{_win32_firefox_process}->GetExitCode( my $exit_code );
            if ( $exit_code != Win32::Process::STILL_ACTIVE() ) {
                $self->{_child_error} = $exit_code;
                delete $self->{_win32_firefox_process};
            }
        }
        if ( $self->{_win32_ssh_process} ) {
            $self->{_win32_ssh_process}->GetExitCode( my $exit_code );
            if ( $exit_code != Win32::Process::STILL_ACTIVE() ) {
                $self->{_child_error} = $exit_code;
                delete $self->{_win32_ssh_process};
            }
        }
        $self->_reap_other_win32_ssh_processes();
    }
    elsif ( my $ssh = $self->_ssh() ) {
        while ( ( my $pid = waitpid _ANYPROCESS(), POSIX::WNOHANG() ) > 0 ) {
            if ( ( $ssh->{pid} ) && ( $pid == $ssh->{pid} ) ) {
                $self->{_child_error} = $CHILD_ERROR;
            }
            elsif ( ( $self->xvfb() ) && ( $pid == $self->xvfb() ) ) {
                $self->{_xvfb_child_error} = $CHILD_ERROR;
                delete $self->{xvfb_pid};
                delete $self->{_xvfb_display_number};
            }
        }
    }
    else {
        while ( ( my $pid = waitpid _ANYPROCESS(), POSIX::WNOHANG() ) > 0 ) {
            if (   ( $self->_firefox_pid() )
                && ( $pid == $self->_firefox_pid() ) )
            {
                $self->{_child_error} = $CHILD_ERROR;
            }
            elsif (( $self->_local_ssh_pid() )
                && ( $pid == $self->_local_ssh_pid() ) )
            {
                $self->{_child_error} = $CHILD_ERROR;
            }
            elsif ( ( $self->xvfb() ) && ( $pid == $self->xvfb() ) ) {
                $self->{_xvfb_child_error} = $CHILD_ERROR;
                delete $self->{xvfb_pid};
                delete $self->{_xvfb_display_number};
            }
        }
    }
    return;
}

sub _reap_other_win32_ssh_processes {
    my ($self) = @_;
    my @other_processes;
    foreach my $process ( @{ $self->{_other_win32_ssh_processes} } ) {
        $process->GetExitCode( my $exit_code );
        if ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
            push @other_processes, $process;
        }
    }
    $self->{_other_win32_ssh_processes} = \@other_processes;
    return;
}

sub _remote_process_running {
    my ( $self, $remote_pid ) = @_;
    my $now = time;
    if (   ( defined $self->{last_remote_alive_status} )
        && ( $self->{last_remote_kill_time} >= $now ) )
    {
        return $self->{last_remote_alive_status};
    }
    $self->{last_remote_kill_time} = $now;
    if ( $self->_remote_uname() eq 'MSWin32' ) {
        return $self->_win32_remote_process_running($remote_pid);
    }
    else {
        return $self->_generic_remote_process_running($remote_pid);
    }
}

sub _win32_remote_process_running {
    my ( $self, $remote_pid ) = @_;
    my $binary    = 'tasklist';
    my @arguments = ( '/FI', q["PID eq ] . $remote_pid . q["] );
    $self->{last_remote_alive_status} = 0;
    foreach my $line ( split /\r?\n/smx, $self->execute( $binary, @arguments ) )
    {
        if ( $line =~ /^firefox[.]exe[ ]+(\d+)[ ]/smx ) {
            if ( $1 == $remote_pid ) {
                $self->{last_remote_alive_status} = 1;
            }
        }
    }
    return $self->{last_remote_alive_status};
}

sub _generic_remote_process_running {
    my ( $self, $remote_pid ) = @_;
    my $binary    = 'kill';
    my @arguments = ( '-0', $remote_pid );
    my $dev_null  = File::Spec->devnull();
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        if ( $CHILD_ERROR == 0 ) {
            $self->{last_remote_alive_status} = 1;
        }
        else {
            $self->{last_remote_alive_status} = 0;
        }
    }
    elsif ( defined $pid ) {
        eval {
            $self->_ssh_exec( $self->_ssh_parameters(),
                $self->_ssh_address(), $binary, @arguments )
              or Firefox::Marionette::Exception->throw(
                "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
        } or do {
            chomp $EVAL_ERROR;
            warn "$EVAL_ERROR\n";
        };
        exit 1;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return $self->{last_remote_alive_status};
}

sub alive {
    my ($self) = @_;
    if ( my $ssh = $self->_ssh() ) {
        $self->_reap();
        if ( defined $ssh->{pid} ) {
            if ( $OSNAME eq 'MSWin32' ) {
                $self->_reap_other_win32_ssh_processes();
                if ( $self->{_win32_ssh_process} ) {
                    $self->{_win32_ssh_process}->GetExitCode( my $exit_code );
                    $self->_reap();
                    if ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
                        return 1;
                    }
                }
                return 0;
            }
            else {
                return kill 0, $ssh->{pid};
            }
        }
        elsif ( $self->_firefox_pid() ) {
            return $self->_remote_process_running( $self->_firefox_pid() );
        }
    }
    elsif ( $OSNAME eq 'MSWin32' ) {
        $self->_reap_other_win32_ssh_processes();
        if ( $self->{_win32_firefox_process} ) {
            $self->{_win32_firefox_process}->GetExitCode( my $exit_code );
            $self->_reap();
            if ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
                return 1;
            }
        }
        return 0;
    }
    elsif ( $self->_firefox_pid() ) {
        $self->_reap();
        return kill 0, $self->_firefox_pid();
    }
    return;
}

sub _ssh_local_path_or_port {
    my ($self) = @_;
    if ( $self->{_ssh}->{use_unix_sockets} ) {
        if ( defined $self->{_ssh_local_directory} ) {
            my $path = File::Spec->catfile( "$self->{_ssh_local_directory}",
                'forward.sock' );
            return $path;
        }
    }
    else {
        my $key = 'ssh_local_tcp_socket';
        if ( !defined $self->{_ssh}->{$key} ) {
            socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0
              or Firefox::Marionette::Exception->throw(
                "Failed to create a socket:$EXTENDED_OS_ERROR");
            bind $socket, Socket::sockaddr_in( 0, Socket::INADDR_LOOPBACK() )
              or Firefox::Marionette::Exception->throw(
                "Failed to bind socket:$EXTENDED_OS_ERROR");
            my $port = ( Socket::sockaddr_in( getsockname $socket ) )[0];
            close $socket
              or Firefox::Marionette::Exception->throw(
                "Failed to close random socket:$EXTENDED_OS_ERROR");
            $self->{_ssh}->{$key} = $port;
        }
        return $self->{_ssh}->{$key};
    }
    return;

}

sub _setup_local_socket_via_ssh_with_control_path {
    my ( $self, $ssh_local_path, $localhost, $port ) = @_;
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        if ( $CHILD_ERROR != 0 ) {
            Firefox::Marionette::Exception->throw(
                    'Failed to forward marionette port from '
                  . $self->_ssh_address() . q[:]
                  . $self->_error_message( 'ssh', $CHILD_ERROR ) );
        }
    }
    elsif ( defined $pid ) {
        eval {
            $self->_ssh_exec(
                $self->_ssh_parameters(),
                '-L', "$ssh_local_path:$localhost:$port",
                '-O', 'forward', $self->_ssh_address()
              )
              or Firefox::Marionette::Exception->throw(
                "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
        } or do {
            if ( $self->_debug() ) {
                chomp $EVAL_ERROR;
                warn "$EVAL_ERROR\n";
            }
        };
        exit 1;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return;
}

sub _setup_local_socket_via_ssh_without_control_path {
    my ( $self, $ssh_local_port, $localhost, $port ) = @_;
    my @ssh_arguments = (
        $self->_ssh_parameters(),
        '-N', '-L', "$ssh_local_port:$localhost:$port",
        $self->_ssh_address(),
    );
    if ( $OSNAME eq 'MSWin32' ) {
        my $process = $self->_start_win32_process( 'ssh', @ssh_arguments );
        push @{ $self->{_other_win32_ssh_processes} }, $process;
    }
    else {
        if ( my $pid = fork ) {
        }
        elsif ( defined $pid ) {
            eval {
                $self->_ssh_exec( @ssh_arguments, )
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
            } or do {
                if ( $self->_debug() ) {
                    chomp $EVAL_ERROR;
                    warn "$EVAL_ERROR\n";
                }
            };
            exit 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to fork:$EXTENDED_OS_ERROR");
        }
    }
    if ( $self->_ssh()->{use_unix_sockets} ) {
        while ( !-e $ssh_local_port ) {
            sleep 1;
        }
    }
    else {
        my $found_port = 0;
        while ( $found_port == 0 ) {
            socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0
              or Firefox::Marionette::Exception->throw(
                "Failed to create a socket:$EXTENDED_OS_ERROR");
            my $sock_addr = Socket::pack_sockaddr_in( $ssh_local_port,
                Socket::inet_aton($localhost) );
            if ( connect $socket, $sock_addr ) {
                $found_port = $ssh_local_port;
            }
            close $socket
              or Firefox::Marionette::Exception->throw(
                "Failed to close test socket:$EXTENDED_OS_ERROR");
        }
    }
    return;
}

sub _setup_local_socket_via_ssh {
    my ( $self, $port ) = @_;
    my $localhost = '127.0.0.1';
    if ( my $ssh = $self->_ssh() ) {
        my $ssh_local_path_or_port = $self->_ssh_local_path_or_port();
        if ( $ssh->{use_control_path} ) {
            my $ssh_local_path = $ssh_local_path_or_port;
            $self->_setup_local_socket_via_ssh_with_control_path(
                $ssh_local_path, $localhost, $port );
            return $ssh_local_path;
        }
        else {
            my $ssh_local_port = $ssh_local_path_or_port;
            $self->_setup_local_socket_via_ssh_without_control_path(
                $ssh_local_port, $localhost, $port );
            return $ssh_local_port;
        }
    }
    return;
}

sub _get_marionette_port_or_undef {
    my ($self) = @_;
    my $port;
    if ( $self->{profile_path} ) {
        $port =
          defined $port && $port > 0 ? $port : $self->_get_marionette_port();
        if ( ( !defined $port ) || ( $port == 0 ) ) {
            sleep 1;
            return;
        }
    }
    return $port;
}

sub _get_sock_addr {
    my ( $self, $host, $port ) = @_;
    my $sock_addr;
    if ( my $ssh = $self->_ssh() ) {
        if ( !-e $self->_ssh_local_path_or_port() ) {
            my $port_or_path = $self->_setup_local_socket_via_ssh($port);
            if ( $ssh->{use_unix_sockets} ) {
                $sock_addr = Socket::pack_sockaddr_un($port_or_path);
            }
            else {
                $sock_addr = Socket::pack_sockaddr_in( $port_or_path,
                    Socket::inet_aton($host) );
            }
        }
        else {
            sleep 1;
            return;
        }
    }
    else {
        $sock_addr =
          Socket::pack_sockaddr_in( $port, Socket::inet_aton($host) );
    }
    return $sock_addr;
}

sub _using_unix_sockets_for_ssh_connection {
    my ($self) = @_;
    if ( my $ssh = $self->_ssh() ) {
        if ( $ssh->{use_unix_sockets} ) {
            return 1;
        }
    }
    return 0;
}

sub _setup_local_connection_to_firefox {
    my ( $self, @arguments ) = @_;
    my $host = _DEFAULT_HOST();
    my $port;
    my $socket;
    my $sock_addr;
    my $connected;
    while ( ( !$connected ) && ( $self->alive() ) ) {
        $socket = undef;
        socket $socket,
          $self->_using_unix_sockets_for_ssh_connection()
          ? Socket::PF_UNIX()
          : Socket::PF_INET(), Socket::SOCK_STREAM(), 0
          or Firefox::Marionette::Exception->throw(
            "Failed to create a socket:$EXTENDED_OS_ERROR");
        binmode $socket;
        $port ||= $self->_get_marionette_port_or_undef();
        next if ( !defined $port );
        $sock_addr ||= $self->_get_sock_addr( $host, $port );
        next if ( !defined $sock_addr );
        if ( connect $socket, $sock_addr ) {
            $connected = 1;
        }
        elsif ( $EXTENDED_OS_ERROR == POSIX::ECONNREFUSED() ) {
            sleep 1;
        }
        elsif (( $OSNAME eq 'MSWin32' )
            && ( $EXTENDED_OS_ERROR == _WIN32_CONNECTION_REFUSED() ) )
        {
            sleep 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to connect to $host on port $port:$EXTENDED_OS_ERROR");
        }
    }
    $self->_reap();
    if ( ( $self->alive() ) && ($socket) ) {
    }
    else {
        my $error_message =
            $self->error_message()
          ? $self->error_message()
          : q[Firefox was not launched];
        Firefox::Marionette::Exception->throw($error_message);
    }
    return $socket;
}

sub _remote_catfile {
    my ( $self, @parts ) = @_;
    if ( ( $self->_remote_uname() ) && ( $self->_remote_uname() eq 'MSWin32' ) )
    {
        return join q[\\], @parts;
    }
    else {
        return join q[/], @parts;
    }
}

sub _ssh_address {
    my ($self) = @_;
    my $address;
    if ( defined $self->{_ssh}->{user} ) {
        $address = join q[], $self->{_ssh}->{user}, q[@], $self->{_ssh}->{host};
    }
    else {
        $address = $self->{_ssh}->{host};
    }
    return $address;
}

sub _ssh_parameters {
    my ( $self, %parameters ) = @_;
    my @parameters = ( '-2', );
    if ( my $ssh = $self->_ssh() ) {
        if ( my $port = $ssh->{port} ) {
            push @parameters, ( '-p' => $port, );
        }
    }
    return ( @parameters, $self->_ssh_common_parameters(%parameters) );
}

sub _ssh_exec {
    my ( $self, @parameters ) = @_;
    if ( $self->_debug() ) {
        warn q[** ] . ( join q[ ], 'ssh', @parameters ) . "\n";
    }
    my $dev_null = File::Spec->devnull();
    open STDERR, q[>], $dev_null
      or Firefox::Marionette::Exception->throw(
        "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR");
    if ( $self->_remote_firefox_tmp_directory() ) {
        local $ENV{TMPDIR} = $self->_remote_firefox_tmp_directory();
        return exec {'ssh'} 'ssh', @parameters;
    }
    else {
        return exec {'ssh'} 'ssh', @parameters;
    }
}

sub _make_remote_directory {
    my ( $self, $path ) = @_;
    if ( $OSNAME eq 'MSWin32' ) {
        if (
            $self->_execute_win32_process(
                'ssh', $self->_ssh_parameters(),
                $self->_ssh_address(), 'mkdir', $path
            )
          )
        {
            return $path;
        }
        else {
            Firefox::Marionette::Exception->throw(
                    'Failed to create directory '
                  . $self->_ssh_address()
                  . ":$path:"
                  . $self->_error_message(
                    'ssh', Win32::FormatMessage( Win32::GetLastError() )
                  )
            );
        }
    }
    else {
        my @mkdir_parameters;
        if ( $self->_remote_uname() ne 'MSWin32' ) {
            push @mkdir_parameters, qw(-m 700);
        }
        if ( my $pid = fork ) {
            waitpid $pid, 0;
            if ( $CHILD_ERROR != 0 ) {
                Firefox::Marionette::Exception->throw(
                        'Failed to create directory '
                      . $self->_ssh_address()
                      . ":$path:"
                      . $self->_error_message( 'ssh', $CHILD_ERROR ) );
            }
            return $path;
        }
        elsif ( defined $pid ) {
            eval {
                $self->_ssh_exec( $self->_ssh_parameters(),
                    $self->_ssh_address(), 'mkdir', @mkdir_parameters, $path )
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
            } or do {
                if ( $self->_debug() ) {
                    chomp $EVAL_ERROR;
                    warn "$EVAL_ERROR\n";
                }
            };
            exit 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to fork:$EXTENDED_OS_ERROR");
        }
    }
    return;
}

sub _root_directory {
    my ($self) = @_;
    if ( !defined $self->{_root_directory} ) {
        $self->{_root_directory} = File::Temp->newdir(
            File::Spec->catdir(
                File::Spec->tmpdir(), 'firefox_marionette_local_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to create temporary directory:$EXTENDED_OS_ERROR");
    }
    return $self->{_root_directory};
}

sub _write_local_proxy {
    my ( $self, $ssh ) = @_;
    my $local_proxy_path;
    if ( defined $ssh ) {
        $local_proxy_path =
          File::Spec->catfile( "$self->{_ssh_local_directory}", 'reconnect' );
    }
    else {
        $local_proxy_path =
          File::Spec->catfile( $self->{_root_directory}, 'reconnect' );
    }
    unlink $local_proxy_path
      or ( $OS_ERROR == POSIX::ENOENT() )
      or Firefox::Marionette::Exception->throw(
        "Failed to unlink $local_proxy_path:$EXTENDED_OS_ERROR");
    my $local_proxy_handle =
      FileHandle->new( $local_proxy_path,
        Fcntl::O_CREAT() | Fcntl::O_EXCL() | Fcntl::O_WRONLY() )
      or Firefox::Marionette::Exception->throw(
        "Failed to open $local_proxy_path for writing:$EXTENDED_OS_ERROR");
    my $local_proxy = {};
    if ( defined $local_proxy->{version} ) {
        foreach my $key (qw(major minor patch)) {
            if ( defined $self->{_initial_version}->{$key} ) {
                $local_proxy->{version}->{$key} =
                  $self->{_initial_version}->{$key};
            }
        }
    }
    if ( defined $ssh ) {
        $local_proxy->{ssh}->{root}   = $self->{_root_directory};
        $local_proxy->{ssh}->{name}   = $self->_remote_uname();
        $local_proxy->{ssh}->{binary} = $self->_binary();
        $local_proxy->{ssh}->{uname}  = $self->_remote_uname();
        foreach my $key (qw(user host port pid)) {
            if ( defined $ssh->{$key} ) {
                $local_proxy->{ssh}->{$key} = $ssh->{$key};
            }
        }
    }
    if ( defined $self->{_xvfb_pid} ) {
        $local_proxy->{xvfb}->{pid} = $self->{_xvfb_pid};
    }
    if ( defined $self->{_firefox_pid} ) {
        $local_proxy->{firefox}->{pid}     = $self->{_firefox_pid};
        $local_proxy->{firefox}->{binary}  = $self->_binary();
        $local_proxy->{firefox}->{version} = $self->{_initial_version};
    }
    $local_proxy_handle->print( JSON::encode_json($local_proxy) )
      or Firefox::Marionette::Exception->throw(
        "Failed to write to $local_proxy_path:$EXTENDED_OS_ERROR");
    $local_proxy_handle->close()
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$local_proxy_path':$EXTENDED_OS_ERROR");
    return;
}

sub _setup_profile_directories {
    my ( $self, $profile ) = @_;
    if ( ($profile) && ( $profile->download_directory() ) ) {
    }
    elsif ( my $ssh = $self->_ssh() ) {
        $self->{_root_directory} = $self->_get_remote_root_directory();
        $self->_write_local_proxy($ssh);
        $self->{_profile_directory} = $self->_make_remote_directory(
            $self->_remote_catfile( $self->{_root_directory}, 'profile' ) );
        $self->{_download_directory} = $self->_make_remote_directory(
            $self->_remote_catfile( $self->{_root_directory}, 'downloads' ) );
        $self->{_remote_tmp_directory} = $self->_make_remote_directory(
            $self->_remote_catfile( $self->{_root_directory}, 'tmp' ) );
    }
    else {
        my $root_directory = $self->_root_directory();
        my $profile_directory =
          File::Spec->catdir( $root_directory, 'profile' );
        mkdir $profile_directory, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
            "Failed to create directory $profile_directory:$EXTENDED_OS_ERROR");
        $self->{_profile_directory} = $profile_directory;
        my $download_directory =
          File::Spec->catdir( $root_directory, 'downloads' );
        mkdir $download_directory, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
            "Failed to create directory $download_directory:$EXTENDED_OS_ERROR"
          );
        $self->{_download_directory} = $download_directory;
        my $tmp_directory = $self->_local_firefox_tmp_directory();
        mkdir $tmp_directory, Fcntl::S_IRWXU()
          or Firefox::Marionette::Exception->throw(
            "Failed to create directory $tmp_directory:$EXTENDED_OS_ERROR");
    }
    return;
}

sub _setup_new_profile {
    my ( $self, $profile, %parameters ) = @_;
    $self->_setup_profile_directories($profile);
    my $profile_path;
    if ( $self->_ssh() ) {
        $profile_path =
          $self->_remote_catfile( $self->{_profile_directory}, 'prefs.js' );
    }
    else {
        $profile_path =
          File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
    }
    $self->{profile_path} = $profile_path;
    if ($profile) {
        if ( !$profile->download_directory() ) {
            my $download_directory = $self->{_download_directory};
            if ( $OSNAME eq 'cygwin' ) {
                $download_directory =
                  $self->execute( 'cygpath', '-s', '-w', $download_directory );
            }
            $profile->download_directory($download_directory);
        }
    }
    else {
        my %profile_parameters = ();
        foreach my $profile_key (qw(chatty seer nightly)) {
            if ( $parameters{$profile_key} ) {
                $profile_parameters{$profile_key} = 1;
            }
        }
        $profile = Firefox::Marionette::Profile->new(%profile_parameters);
        my $download_directory = $self->{_download_directory};
        if (   ( $self->_remote_uname() )
            && ( $self->_remote_uname() eq 'cygwin' ) )
        {
            $download_directory =
              $self->_execute_via_ssh( {}, 'cygpath', '-s', '-w',
                $download_directory );
            chomp $download_directory;
        }
        $profile->download_directory($download_directory);
        my $bookmarks_path = $self->_setup_empty_bookmarks();
        $profile->set_value( 'browser.bookmarks.file', $bookmarks_path, 1 );
        if ( !$parameters{chatty} ) {
            my $port = $self->_get_local_port_for_profile_urls();
            $profile->set_value( 'media.gmp-manager.url',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'app.update.url',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'app.update.url.manual',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'browser.newtabpage.directory.ping',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'browser.newtabpage.directory.source',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'browser.selfsupport.url',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'extensions.systemAddon.update.url',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'dom.push.serverURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'services.settings.server',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'browser.safebrowsing.gethashURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'browser.safebrowsing.keyURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value(
                'browser.safebrowsing.provider.mozilla.updateURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value(
                'browser.safebrowsing.provider.mozilla.gethashURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value(
                'browser.safebrowsing.provider.google.updateURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value(
                'browser.safebrowsing.provider.google4.updateURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'browser.safebrowsing.updateURL',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'extensions.shield-recipe-client.api_url',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'geo.provider-country.network.url',
                q[http://localhost:] . $port, 1 );
            $profile->set_value( 'geo.wifi.uri',
                q[http://localhost:] . $port, 1 );
        }
    }
    my $mime_types = join q[,], $self->mime_types();
    $profile->set_value( 'browser.helperApps.neverAsk.saveToDisk',
        $mime_types );
    if ( !$self->_is_auto_listen_okay() ) {
        socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0
          or Firefox::Marionette::Exception->throw(
            "Failed to create a socket:$EXTENDED_OS_ERROR");
        bind $socket, Socket::sockaddr_in( 0, Socket::INADDR_LOOPBACK() )
          or Firefox::Marionette::Exception->throw(
            "Failed to bind socket:$EXTENDED_OS_ERROR");
        my $port = ( Socket::sockaddr_in( getsockname $socket ) )[0];
        close $socket
          or Firefox::Marionette::Exception->throw(
            "Failed to close random socket:$EXTENDED_OS_ERROR");
        $profile->set_value( 'marionette.defaultPrefs.port', $port );
        $profile->set_value( 'marionette.port',              $port );
    }
    if ( $self->_ssh() ) {
        $self->_save_profile_via_ssh($profile);
    }
    else {
        $profile->save($profile_path);
    }
    return $self->{_profile_directory};
}

sub _get_local_port_for_profile_urls {
    my ($self) = @_;
    socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0
      or Firefox::Marionette::Exception->throw(
        "Failed to create a socket:$EXTENDED_OS_ERROR");
    bind $socket, Socket::sockaddr_in( 0, Socket::INADDR_LOOPBACK() )
      or Firefox::Marionette::Exception->throw(
        "Failed to bind socket:$EXTENDED_OS_ERROR");
    my $port = ( Socket::sockaddr_in( getsockname $socket ) )[0];
    close $socket
      or Firefox::Marionette::Exception->throw(
        "Failed to close random socket:$EXTENDED_OS_ERROR");
    return $port;
}

sub _setup_empty_bookmarks {
    my ($self)            = @_;
    my $now               = time;
    my $profile_directory = $self->{_profile_directory};
    my $content           = <<"_HTML_";
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>

<DL><p>
    <DT><H3 ADD_DATE="$now" LAST_MODIFIED="$now" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3>
    <DL><p>
    </DL><p>
    <DT><H3 ADD_DATE="$now" LAST_MODIFIED="$now" UNFILED_BOOKMARKS_FOLDER="true">Other Bookmarks</H3>
    <DL><p>
    </DL><p>
</DL>
_HTML_
    my $path;
    if ( $self->_ssh() ) {
        my $handle = File::Temp::tempfile(
            File::Spec->catfile(
                File::Spec->tmpdir(),
                'firefox_marionette_local_bookmarks_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
        print {$handle} $content
          or Firefox::Marionette::Exception->throw(
            "Failed to write to temporary file:$EXTENDED_OS_ERROR");
        seek $handle, 0, Fcntl::SEEK_SET()
          or Firefox::Marionette::Exception->throw(
            "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
        $path = $self->_remote_catfile( $profile_directory, 'bookmarks.html' );
        $self->_put_file_via_scp( $handle, $path, 'bookmarks.html' );
        if ( $self->_remote_uname() eq 'cygwin' ) {
            $path = $self->_execute_via_ssh( {}, 'cygpath', '-l', '-w', $path );
            chomp $path;
        }
    }
    else {
        $path = File::Spec->catfile( $profile_directory, 'bookmarks.html' );
        my $handle =
          FileHandle->new( $path,
            Fcntl::O_CREAT() | Fcntl::O_EXCL() | Fcntl::O_WRONLY() )
          or Firefox::Marionette::Exception->throw(
            "Failed to open $path for writing:$EXTENDED_OS_ERROR");
        $handle->print($content)
          or Firefox::Marionette::Exception->throw(
            "Failed to write to $path:$EXTENDED_OS_ERROR");
        $handle->close()
          or Firefox::Marionette::Exception->throw(
            "Failed to close '$path':$EXTENDED_OS_ERROR");
    }
    return $path;
}

sub _save_profile_via_ssh {
    my ( $self, $profile ) = @_;
    my $handle = File::Temp::tempfile(
        File::Spec->catfile(
            File::Spec->tmpdir(),
            'firefox_marionette_saved_profile_XXXXXXXXXXX'
        )
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    print {$handle} $profile->as_string()
      or Firefox::Marionette::Exception->throw(
        "Failed to write to temporary file:$EXTENDED_OS_ERROR");
    seek $handle, 0, Fcntl::SEEK_SET()
      or Firefox::Marionette::Exception->throw(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    $self->_put_file_via_scp( $handle, $self->{profile_path}, 'profile data' );
    return;
}

sub _get_local_handle_for_generic_command_output {
    my ( $self, $parameters, $binary, @arguments ) = @_;
    my $dev_null = File::Spec->devnull();
    my $handle   = FileHandle->new();
    if ( my $pid = $handle->open(q[-|]) ) {
    }
    elsif ( defined $pid ) {
        eval {
            if ( $parameters->{capture_stderr} ) {
                open STDERR, '>&', ( fileno STDOUT )
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDERR to STDOUT:$EXTENDED_OS_ERROR");
            }
            elsif (( defined $parameters->{stderr} )
                && ( $parameters->{stderr} == 0 ) )
            {
                open STDERR, q[>], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            else {
                open STDERR, q[>], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            if ( $self->_remote_firefox_tmp_directory() ) {
                local $ENV{TMPDIR} = $self->_remote_firefox_tmp_directory();
                exec {$binary} $binary, @arguments
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec $binary:$EXTENDED_OS_ERROR");
            }
            else {
                exec {$binary} $binary, @arguments
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec $binary:$EXTENDED_OS_ERROR");
            }
        } or do {
            chomp $EVAL_ERROR;
            warn "$EVAL_ERROR\n";
        };
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return $handle;
}

sub _get_local_command_output {
    my ( $self, $parameters, $binary, @arguments ) = @_;
    my $output;
    my $handle;
    if ( $OSNAME eq 'MSWin32' ) {
        my $shell_command = _quoting_for_cmd_exe( $binary, @arguments );
        if ( $parameters->{capture_stderr} ) {
            $shell_command = "\"$shell_command 2>&1\"";
        }
        else {
            $shell_command .= ' 2>nul';
        }
        if ( $self->_debug() ) {
            warn q[** ] . $shell_command . "\n";
        }
        $handle = FileHandle->new("$shell_command |");
    }
    else {
        if ( $self->_debug() ) {
            warn q[** ] . ( join q[ ], $binary, @arguments ) . "\n";
        }
        $handle =
          $self->_get_local_handle_for_generic_command_output( $parameters,
            $binary, @arguments );
    }
    my $result;
    while ( $result = $handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() ) ) {
        $output .= $buffer;
    }
    defined $result
      or Firefox::Marionette::Exception->throw( "Failed to read from $binary "
          . ( join q[ ], @arguments )
          . ":$EXTENDED_OS_ERROR" );
    $handle->close()
      or $parameters->{ignore_exit_status}
      or Firefox::Marionette::Exception->throw( q[Command ']
          . ( join q[ ], $binary, @arguments )
          . q[ did not complete successfully:]
          . $self->_error_message( $binary, $CHILD_ERROR ) );
    return $output;
}

sub _ssh_client_version {
    my ($self) = @_;
    my $key = '_ssh_client_version';
    if ( !defined $self->{$key} ) {
        foreach my $line (
            split /\r?\n/smx,
            $self->_get_local_command_output(
                { capture_stderr => 1 },
                'ssh', '-V'
            )
          )
        {
            if ( $line =~ /^OpenSSH(?:_for_Windows)?_(\d+[.]\d+(?:p\d+)),/smx )
            {
                ( $self->{$key} ) = ($1);
            }
        }
    }
    return $self->{$key};
}

sub _scp_t_ok {
    my ($self) = @_;
    if ( $self->_ssh_client_version() =~ /^[1234567][.]/smx ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _scp_parameters {
    my ( $self, %parameters ) = @_;
    my @parameters = qw(-p);
    if ( $self->_scp_t_ok() ) {
        push @parameters, qw(-T);
    }
    if ( my $ssh = $self->_ssh() ) {
        if ( my $port = $ssh->{port} ) {
            push @parameters, ( '-P' => $port, );
        }
    }
    return ( @parameters, $self->_ssh_common_parameters(%parameters) );
}

sub _ssh_common_parameters {
    my ( $self, %parameters ) = @_;
    my @parameters = (
        '-q',
        '-o' => 'ServerAliveInterval=15',
        '-o' => 'BatchMode=yes',
        '-o' => 'ExitOnForwardFailure=yes',
    );
    if (   ( $parameters{master} )
        || ( $parameters{env} ) )
    {
        push @parameters, ( '-o' => 'SendEnv=TMPDIR' );
    }
    if ( $parameters{accept_new} ) {
        push @parameters, ( '-o' => 'StrictHostKeyChecking=accept-new' );
    }
    else {
        push @parameters, ( '-o' => 'StrictHostKeyChecking=yes' );
    }
    if (   ( $parameters{master} )
        && ( $self->{_ssh} )
        && ( $self->{_ssh}->{use_control_path} ) )
    {
        push @parameters,
          (
            '-o' => 'ControlPath=' . $self->_control_path(),
            '-o' => 'ControlMaster=yes',
            '-o' => 'ControlPersist=30',
          );
    }
    elsif ( ( $self->{_ssh} ) && ( $self->{_ssh}->{use_control_path} ) ) {
        push @parameters,
          (
            '-o' => 'ControlPath=' . $self->_control_path(),
            '-o' => 'ControlMaster=no',
          );
    }
    return @parameters;
}

sub _system {
    my ( $self, $binary, @arguments ) = @_;
    my $command_line;
    my $result;
    if ( $OSNAME eq 'MSWin32' ) {
        $command_line = _quoting_for_cmd_exe( $binary, @arguments );
        if ( $self->_execute_win32_process( $binary, @arguments ) ) {
            $result = 0;
        }
        else {
            $result = 1;
        }
    }
    else {
        $command_line = join q[ ], $binary, @arguments;
        if ( $self->_debug() ) {
            warn q[** ] . $command_line . "\n";
        }
        $result = system $binary, @arguments;
    }
    if ( $result == 0 ) {
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to successfully execute $command_line:"
              . $self->_error_message( $binary, $CHILD_ERROR ) );
    }
    return;
}

sub _get_file_via_scp {
    my ( $self, $remote_path, $description ) = @_;
    $self->{_scp_get_file_index} += 1;
    my $local_name = 'file_' . $self->{_scp_get_file_index} . '.dat';
    my $local_path =
      File::Spec->catfile( $self->{_local_scp_get_directory}, $local_name );
    if ( $OSNAME eq 'MSWin32' ) {
        $remote_path = _quoting_for_cmd_exe($remote_path);
    }
    my @parameters = (
        $self->_scp_parameters(),
        $self->_ssh_address() . ":\"$remote_path\"", $local_path,
    );
    $self->_system( 'scp', @parameters );
    my $handle = FileHandle->new( $local_path, Fcntl::O_RDONLY() )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$local_path' for reading:$EXTENDED_OS_ERROR");
    binmode $handle;

    if (   ( $OSNAME eq 'MSWin32' )
        || ( $OSNAME eq 'cygwin' ) )
    {
    }
    else {
        unlink $local_path
          or Firefox::Marionette::Exception->throw(
            "Failed to unlink '$local_path':$EXTENDED_OS_ERROR");
    }
    return $handle;
}

sub _put_file_via_scp {
    my ( $self, $original_handle, $remote_path, $description ) = @_;
    $self->{_scp_put_file_index} += 1;
    my $local_name = 'file_' . $self->{_scp_put_file_index} . '.dat';
    my $local_path =
      File::Spec->catfile( $self->{_local_scp_put_directory}, $local_name );
    my $temp_handle = FileHandle->new(
        $local_path,
        Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$local_path' for writing:$EXTENDED_OS_ERROR");
    binmode $temp_handle;
    my $result;
    while ( $result =
        $original_handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() ) )
    {
        $temp_handle->print($buffer)
          or Firefox::Marionette::Exception->throw(
            "Failed to write to '$local_path':$EXTENDED_OS_ERROR");
    }
    defined $result
      or Firefox::Marionette::Exception->throw(
        "Failed to read from $description:$EXTENDED_OS_ERROR");
    close $temp_handle
      or Firefox::Marionette::Exception->throw(
        "Failed to close $local_path:$EXTENDED_OS_ERROR");
    if ( $OSNAME eq 'MSWin32' ) {
        $remote_path = _quoting_for_cmd_exe($remote_path);
    }
    my @parameters = (
        $self->_scp_parameters(),
        $local_path, $self->_ssh_address() . ":\"$remote_path\"",
    );
    $self->_system( 'scp', @parameters );
    unlink $local_path
      or Firefox::Marionette::Exception->throw(
        "Failed to unlink $local_path:$EXTENDED_OS_ERROR");
    return;
}

sub _initialise_remote_uname {
    my ($self) = @_;
    if ( defined $self->{_remote_uname} ) {
    }
    else {
        my $uname;
        my $command = 'uname || ver';
        foreach my $line ( split /\r?\n/smx, $self->execute($command) ) {
            $line =~ s/[\r\n]//smxg;
            if ( ($line) && ( $line =~ /^Microsoft[ ]Windows[ ]/smx ) ) {
                $uname = 'MSWin32';
            }
            elsif ( ($line) && ( $line =~ /^CYGWIN_NT/smx ) ) {
                $uname = 'cygwin';
            }
            elsif ($line) {
                $uname = lc $line;
            }
        }
        $self->{_remote_uname} = $uname;
        chomp $self->{_remote_uname};
    }
    return;
}

sub _remote_uname {
    my ($self) = @_;
    return $self->{_remote_uname};
}

sub _get_marionette_port_via_ssh {
    my ($self) = @_;
    my $handle;
    my $sandbox_regex = $self->_sandbox_regex();
    $self->_initialise_remote_uname();
    if ( $self->_remote_uname() eq 'MSWin32' ) {
        $handle =
          $self->_get_file_via_scp( $self->{profile_path}, 'profile path' );
    }
    else {
        $handle = $self->_search_file_via_ssh(
            $self->{profile_path},
            'profile path',
            [
                'marionette\\.port',
                'security\\.sandbox\\.content\\.tempDirSuffix',
                'security\\.sandbox\\.plugin\\.tempDirSuffix'
            ]
        );
    }
    my $port;
    while ( my $line = <$handle> ) {
        if ( $line =~ /^user_pref[(]"marionette[.]port",[ ]*(\d+)[)];\s*$/smx )
        {
            $port = $1;
        }
        elsif ( $line =~
            /^user_pref[(]"$sandbox_regex",[ ]*"[{]?([^"}]+)[}]?"[)];\s*$/smx )
        {
            my ( $sandbox, $uuid ) = ( $1, $2 );
            $self->{_ssh}->{sandbox}->{$sandbox} = $uuid;
        }
    }
    return $port;
}

sub _search_file_via_ssh {
    my ( $self, $path, $description, $patterns ) = @_;
    my $output = $self->_execute_via_ssh( {}, 'grep',
        ( map { ( q[-e], $_ ) } @{$patterns} ), $path );
    my $handle = File::Temp::tempfile(
        File::Spec->catfile(
            File::Spec->tmpdir(),
            'firefox_marionette_search_file_via_ssh_XXXXXXXXXXX'
        )
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    $handle->print($output)
      or Firefox::Marionette::Exception->throw(
        "Failed to write to temporary file:$EXTENDED_OS_ERROR");
    $handle->seek( 0, Fcntl::SEEK_SET() )
      or Firefox::Marionette::Exception->throw(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    return $handle;
}

sub _get_marionette_port {
    my ($self) = @_;
    my $port;
    if ( my $ssh = $self->_ssh() ) {
        $port = $self->_get_marionette_port_via_ssh();
    }
    else {
        my $profile_handle =
          FileHandle->new( $self->{profile_path}, Fcntl::O_RDONLY() )
          or ( ( $OSNAME eq 'MSWin32' )
            && ( $EXTENDED_OS_ERROR == _WIN32_ERROR_SHARING_VIOLATION() ) )
          or Firefox::Marionette::Exception->throw(
"Failed to open '$self->{profile_path}' for reading:$EXTENDED_OS_ERROR"
          );
        if ($profile_handle) {
            while ( my $line = <$profile_handle> ) {
                if ( $line =~
                    /^user_pref[(]"marionette.port",[ ]*(\d+)[)];\s*$/smx )
                {
                    $port = $1;
                }
            }
            $profile_handle->close()
              or Firefox::Marionette::Exception->throw(
                "Failed to close '$self->{profile_path}':$EXTENDED_OS_ERROR");
        }
    }
    return $port;
}

sub _initial_socket_setup {
    my ( $self, $socket, $capabilities ) = @_;
    $self->{_socket} = $socket;
    my $initial_response = $self->_read_from_socket();
    $self->{marionette_protocol} = $initial_response->{marionetteProtocol};
    $self->{application_type}    = $initial_response->{applicationType};
    $self->_compatibility_checks_for_older_marionette();
    return $self->new_session($capabilities);
}

sub _request_proxy {
    my ( $self, $proxy ) = @_;
    my $build = {};
    if ( $proxy->type() ) {
        $build->{proxyType} = $proxy->type();
    }
    elsif ( $proxy->pac() ) {
        $build->{proxyType} = 'pac';
    }
    if ( $proxy->pac() ) {
        $build->{proxyAutoconfigUrl} = $proxy->pac()->as_string();
    }
    if ( $proxy->ftp() ) {
        $build->{proxyType} ||= 'manual';
        $build->{ftpProxy} = $proxy->ftp();
    }
    if ( $proxy->http() ) {
        $build->{proxyType} ||= 'manual';
        $build->{httpProxy} = $proxy->http();
    }
    if ( $proxy->none() ) {
        $build->{proxyType} ||= 'manual';
        $build->{noProxy} = [ $proxy->none() ];
    }
    if ( $proxy->https() ) {
        $build->{proxyType} ||= 'manual';
        $build->{sslProxy} = $proxy->https();
    }
    if ( $proxy->socks() ) {
        $build->{proxyType} ||= 'manual';
        $build->{socksProxy} = $proxy->socks();
    }
    if ( $proxy->socks_version() ) {
        $build->{proxyType} ||= 'manual';
        $build->{socksProxyVersion} = $build->{socksVersion} =
          $proxy->socks_version() + 0;
    }
    elsif ( $proxy->socks() ) {
        $build->{proxyType} ||= 'manual';
        $build->{socksProxyVersion} = $build->{socksVersion} =
          _DEFAULT_SOCKS_VERSION();
    }
    return $self->_convert_proxy_before_request($build);
}

sub _convert_proxy_before_request {
    my ( $self, $build ) = @_;
    if ( defined $build ) {
        foreach my $key (qw(ftpProxy socksProxy sslProxy httpProxy)) {
            if ( defined $build->{$key} ) {
                if ( !$self->_is_new_hostport_okay() ) {
                    if ( $build->{$key} =~ s/:(\d+)$//smx ) {
                        $build->{ $key . 'Port' } = $1 + 0;
                    }
                }
            }
        }
    }
    return $build;
}

sub _proxy_from_env {
    my ($self) = @_;
    my $build;
    foreach my $key (qw(ftp all https http)) {
        my $full_name = $key . '_proxy';
        if ( $ENV{$full_name} ) {
        }
        elsif ( $ENV{ uc $full_name } ) {
            $full_name = uc $full_name;
        }
        if ( $ENV{$full_name} ) {
            $build->{proxyType} = 'manual';
            my $value = $ENV{$full_name};
            if ( $value !~ /^\w+:\/\//smx ) { # add an http scheme if none exist
                $value = 'http://' . $value;
            }
            my $uri       = URI->new($value);
            my $build_key = $key;
            if ( $key eq 'https' ) {
                $build_key = 'ssl';
            }
            $build->{ $build_key . 'Proxy' } = $uri->host_port();
        }
    }
    return $self->_convert_proxy_before_request($build);
}

sub _new_session_parameters {
    my ( $self, $capabilities ) = @_;
    my $parameters = {};
    $parameters->{capabilities}->{requiredCapabilities} =
      {};    # for Mozilla 50 (and below???)
    if (   ( defined $capabilities )
        && ( ref $capabilities )
        && ( ref $capabilities eq 'Firefox::Marionette::Capabilities' ) )
    {
        my $actual   = {};
        my %booleans = (
            set_window_rect             => 'setWindowRect',
            accept_insecure_certs       => 'acceptInsecureCerts',
            moz_webdriver_click         => 'moz:webdriverClick',
            strict_file_interactability => 'strictFileInteractability',
            moz_use_non_spec_compliant_pointer_origin =>
              'moz:useNonSpecCompliantPointerOrigin',
            moz_accessibility_checks => 'moz:accessibilityChecks',
        );
        foreach my $method ( sort { $a cmp $b } keys %booleans ) {
            if ( defined $capabilities->$method() ) {
                $actual->{ $booleans{$method} } =
                  $capabilities->$method() ? \1 : \0;
            }
        }
        if ( defined $capabilities->page_load_strategy() ) {
            $actual->{pageLoadStrategy} = $capabilities->page_load_strategy();
        }
        if ( defined $capabilities->unhandled_prompt_behavior() ) {
            $actual->{unhandledPromptBehavior} =
              $capabilities->unhandled_prompt_behavior();
        }
        if ( $capabilities->proxy() ) {
            $actual->{proxy} = $self->_request_proxy( $capabilities->proxy() );
        }
        elsif ( my $env_proxy = $self->_proxy_from_env() ) {
            $actual->{proxy} = $env_proxy;
        }
        $parameters = $actual;    # for Mozilla 57 and after
        foreach my $key ( sort { $a cmp $b } keys %{$actual} ) {
            $parameters->{capabilities}->{requiredCapabilities}->{$key} =
              $actual->{$key};    # for Mozilla 56 (and below???)
        }
        $parameters->{capabilities}->{requiredCapabilities} ||=
          {};                     # for Mozilla 50 (and below???)
    }
    elsif ( my $env_proxy = $self->_proxy_from_env() ) {
        $parameters->{proxy} = $env_proxy;    # for Mozilla 57 and after
        $parameters->{capabilities}->{requiredCapabilities}->{proxy} =
          $env_proxy;                         # for Mozilla 56 (and below???)
    }
    return $parameters;
}

sub new_session {
    my ( $self, $capabilities ) = @_;
    my $parameters = $self->_new_session_parameters($capabilities);
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),                              $message_id,
            $self->_command('WebDriver:NewSession'), $parameters
        ]
    );
    my $response = $self->_get_response($message_id);
    $self->{session_id} = $response->result()->{sessionId};
    my $new;
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        $new =
          $self->_create_capabilities( $response->result()->{capabilities} );
    }
    elsif ( ref $response->result()->{value} ) {
        $new =
          $self->_create_capabilities( $response->result()->{value} );
    }
    else {
        $new = $self->capabilities();
    }
    $self->{_browser_version} = $new->browser_version();

    if ( ( defined $capabilities ) && ( defined $capabilities->timeouts() ) ) {
        $self->timeouts( $capabilities->timeouts() );
        $new->timeouts( $capabilities->timeouts() );
    }
    return ( $self->{session_id}, $new );
}

sub browser_version {
    my ($self) = @_;
    if ( defined $self->{_browser_version} ) {
        return $self->{_browser_version};
    }
    elsif ( defined $self->{_initial_version} ) {
        return join q[.],
          map { defined $_ ? $_ : () } $self->{_initial_version}->{major},
          $self->{_initial_version}->{minor},
          $self->{_initial_version}->{patch};
    }
    else {
        return;
    }
}

sub _create_capabilities {
    my ( $self, $parameters ) = @_;
    my $pid = $parameters->{'moz:processID'} || $parameters->{processId};
    if ( ($pid) && ( $OSNAME eq 'cygwin' ) ) {
        $pid = $self->_firefox_pid();
    }
    my $headless = $self->_visible() ? 0 : 1;
    if ( defined $parameters->{'moz:headless'} ) {
        my $firefox_headless = $parameters->{'moz:headless'} ? 1 : 0;
        if ( $firefox_headless != $headless ) {
            Firefox::Marionette::Exception->throw(
                'moz:headless has not been determined correctly');
        }
    }
    else {
        $parameters->{'moz:headless'} = $headless;
    }
    if ( !defined $self->{_page_load_timeouts_key} ) {
        if ( $parameters->{timeouts} ) {
            if ( defined $parameters->{timeouts}->{'page load'} ) {
                $self->{_page_load_timeouts_key} = 'page load';
            }
            else {
                $self->{_page_load_timeouts_key} = 'pageLoad';
            }
        }
        else {
            $self->{_no_timeouts_command}    = {};
            $self->{_page_load_timeouts_key} = 'pageLoad';
            $self->timeouts(
                Firefox::Marionette::Timeouts->new(
                    page_load => _DEFAULT_PAGE_LOAD_TIMEOUT(),
                    script    => _DEFAULT_SCRIPT_TIMEOUT(),
                    implicit  => _DEFAULT_IMPLICIT_TIMEOUT(),
                )
            );
        }
    }
    elsif ( $self->{_no_timeouts_command} ) {
        $parameters->{timeouts} = {
            $self->{_page_load_timeouts_key} =>
              $self->{_no_timeouts_command}->page_load(),
            script   => $self->{_no_timeouts_command}->script(),
            implicit => $self->{_no_timeouts_command}->implicit(),
        };
    }
    my %optional = $self->_get_optional_capabilities($parameters);

    return Firefox::Marionette::Capabilities->new(
        timeouts => Firefox::Marionette::Timeouts->new(
            page_load =>
              $parameters->{timeouts}->{ $self->{_page_load_timeouts_key} },
            script   => $parameters->{timeouts}->{script},
            implicit => $parameters->{timeouts}->{implicit},
        ),
        browser_version => defined $parameters->{browserVersion}
        ? $parameters->{browserVersion}
        : $parameters->{version},
        platform_name => defined $parameters->{platformName}
        ? $parameters->{platformName}
        : $parameters->{platform},
        rotatable        => $parameters->{rotatable} ? 1 : 0,
        platform_version => $parameters->{platformVersion},
        moz_profile      => $parameters->{'moz:profile'}
          || $self->{_profile_directory},
        moz_process_id => $pid,
        moz_build_id   => $parameters->{'moz:buildID'}
          || $parameters->{appBuildId},
        browser_name => $parameters->{browserName},
        moz_headless => $headless,
        %optional,
    );
}

sub _get_optional_capabilities {
    my ( $self, $parameters ) = @_;
    my %optional;
    if (   ( defined $parameters->{proxy} )
        && ( keys %{ $parameters->{proxy} } ) )
    {
        $optional{proxy} = Firefox::Marionette::Proxy->new(
            $self->_response_proxy( $parameters->{proxy} ) );
    }
    if ( defined $parameters->{'moz:accessibilityChecks'} ) {
        $optional{moz_accessibility_checks} =
          $parameters->{'moz:accessibilityChecks'} ? 1 : 0;
    }
    if ( defined $parameters->{strictFileInteractability} ) {
        $optional{strict_file_interactability} =
          $parameters->{strictFileInteractability} ? 1 : 0;
    }
    if ( defined $parameters->{'moz:shutdownTimeout'} ) {
        $optional{moz_shutdown_timeout} = $parameters->{'moz:shutdownTimeout'};
    }
    if ( defined $parameters->{unhandledPromptBehavior} ) {
        $optional{unhandled_prompt_behavior} =
          $parameters->{unhandledPromptBehavior};
    }
    if ( defined $parameters->{setWindowRect} ) {
        $optional{set_window_rect} = $parameters->{setWindowRect} ? 1 : 0;
    }
    if ( defined $parameters->{'moz:webdriverClick'} ) {
        $optional{moz_webdriver_click} =
          $parameters->{'moz:webdriverClick'} ? 1 : 0;
    }
    if ( defined $parameters->{acceptInsecureCerts} ) {
        $optional{accept_insecure_certs} =
          $parameters->{acceptInsecureCerts} ? 1 : 0;
    }
    if ( defined $parameters->{pageLoadStrategy} ) {
        $optional{page_load_strategy} = $parameters->{pageLoadStrategy};
    }
    if ( defined $parameters->{'moz:useNonSpecCompliantPointerOrigin'} ) {
        $optional{moz_use_non_spec_compliant_pointer_origin} =
          $parameters->{'moz:useNonSpecCompliantPointerOrigin'} ? 1 : 0;
    }
    return %optional;
}

sub _response_proxy {
    my ( $self, $parameters ) = @_;
    my %proxy;
    if ( defined $parameters->{proxyType} ) {
        $proxy{type} = $parameters->{proxyType};
    }
    if ( defined $parameters->{proxyAutoconfigUrl} ) {
        $proxy{pac} = $parameters->{proxyAutoconfigUrl};
    }
    if ( defined $parameters->{ftpProxy} ) {
        $proxy{ftp} = $parameters->{ftpProxy};
        if ( $parameters->{ftpProxyPort} ) {
            $proxy{ftp} .= q[:] . $parameters->{ftpProxyPort};
        }
    }
    if ( defined $parameters->{httpProxy} ) {
        $proxy{http} = $parameters->{httpProxy};
        if ( $parameters->{httpProxyPort} ) {
            $proxy{http} .= q[:] . $parameters->{httpProxyPort};
        }
    }
    if ( defined $parameters->{sslProxy} ) {
        $proxy{https} = $parameters->{sslProxy};
        if ( $parameters->{sslProxyPort} ) {
            $proxy{https} .= q[:] . $parameters->{sslProxyPort};
        }
    }
    if ( defined $parameters->{noProxy} ) {
        $proxy{none} = $parameters->{noProxy};
    }
    if ( defined $parameters->{socksProxy} ) {
        $proxy{socks} = $parameters->{socksProxy};
        if ( $parameters->{socksProxyPort} ) {
            $proxy{socks} .= q[:] . $parameters->{socksProxyPort};
        }
    }
    if ( defined $parameters->{socksProxyVersion} ) {
        $proxy{socks_version} = $parameters->{socksProxyVersion};
    }
    elsif ( defined $parameters->{socksVersion} ) {
        $proxy{socks_version} = $parameters->{socksVersion};
    }
    return %proxy;
}

sub find_elements {
    my ( $self, $value, $using ) = @_;
    Carp::carp(
        '**** DEPRECATED METHOD - find_elements HAS BEEN REPLACED BY find ****'
    );
    return $self->_find( $value, $using );
}

sub list {
    my ( $self, $value, $using, $from ) = @_;
    Carp::carp('**** DEPRECATED METHOD - list HAS BEEN REPLACED BY find ****');
    return $self->_find( $value, $using, $from );
}

sub list_by_id {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
        '**** DEPRECATED METHOD - list_by_id HAS BEEN REPLACED BY find_id ****'
    );
    return $self->_find( $value, 'id', $from );
}

sub list_by_name {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - list_by_name HAS BEEN REPLACED BY find_name ****'
    );
    return $self->_find( $value, 'name', $from );
}

sub list_by_tag {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - list_by_tag HAS BEEN REPLACED BY find_tag ****'
    );
    return $self->_find( $value, 'tag name', $from );
}

sub list_by_class {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - list_by_class HAS BEEN REPLACED BY find_class ****'
    );
    return $self->_find( $value, 'class name', $from );
}

sub list_by_selector {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - list_by_selector HAS BEEN REPLACED BY find_selector ****'
    );
    return $self->_find( $value, 'css selector', $from );
}

sub list_by_link {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - list_by_link HAS BEEN REPLACED BY find_link ****'
    );
    return $self->_find( $value, 'link text', $from );
}

sub list_by_partial {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - list_by_partial HAS BEEN REPLACED BY find_partial ****'
    );
    return $self->_find( $value, 'partial link text', $from );
}

sub add_cookie {
    my ( $self, $cookie ) = @_;
    my $domain = $cookie->domain();
    if ( !defined $domain ) {
        my $uri = $self->uri();
        if ($uri) {
            my $obj = URI->new($uri);
            $domain = $obj->host();
        }
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebDriver:AddCookie'),
            {
                cookie => {
                    httpOnly => $cookie->http_only() ? \1
                    : \0,
                    secure => $cookie->secure() ? \1 : \0,
                    domain => $domain,
                    path   => $cookie->path(),
                    value  => $cookie->value(),
                    (
                        defined $cookie->expiry()
                        ? ( expiry => $cookie->expiry() )
                        : ()
                    ),
                    (
                        defined $cookie->same_site()
                        ? ( sameSite => $cookie->same_site() )
                        : ()
                    ),
                    name => $cookie->name()
                }
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub add_header {
    my ( $self, %headers ) = @_;
    while ( ( my $name, my $value ) = each %headers ) {
        $self->{_headers}->{$name} ||= [];
        push @{ $self->{_headers}->{$name} }, { value => $value, merge => 1 };
    }
    $self->_set_headers();
    return $self;
}

sub add_site_header {
    my ( $self, $host, %headers ) = @_;
    while ( ( my $name, my $value ) = each %headers ) {
        $self->{_site_headers}->{$host}->{$name} ||= [];
        push @{ $self->{_site_headers}->{$host}->{$name} },
          { value => $value, merge => 1 };
    }
    $self->_set_headers();
    return $self;
}

sub delete_header {
    my ( $self, @names ) = @_;
    foreach my $name (@names) {
        $self->{_headers}->{$name}         = [ { value => q[], merge => 0 } ];
        $self->{_deleted_headers}->{$name} = 1;
    }
    $self->_set_headers();
    return $self;
}

sub delete_site_header {
    my ( $self, $host, @names ) = @_;
    foreach my $name (@names) {
        $self->{_site_headers}->{$host}->{$name} =
          [ { value => q[], merge => 0 } ];
        $self->{_deleted_site_headers}->{$host}->{$name} = 1;
    }
    $self->_set_headers();
    return $self;
}

sub _validate_request_header_merge {
    my ( $self, $merge ) = @_;
    if ($merge) {
        return 'true';
    }
    else {
        return 'false';
    }

}

sub _set_headers {
    my ($self) = @_;
    $self->context('chrome');
    my $script = <<'_JS_';
if (typeof PerlFirefoxMarionette == "undefined" ) {
    PerlFirefoxMarionette = {};
} else {
    PerlFirefoxMarionette.headers.unregister();
}
PerlFirefoxMarionette.headers =
{ 
  observe: function(subject, topic, data) {
    this.onHeaderChanged(subject.QueryInterface(Components.interfaces.nsIHttpChannel), topic, data);
  },

  register: function() {
    var observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
    observerService.addObserver(this, "http-on-modify-request", false);
  },

  unregister: function() {
    var observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
    observerService.removeObserver(this, "http-on-modify-request");
  },

  onHeaderChanged: function(channel, topic, data) {
    var host = channel.URI.host;
_JS_
    foreach my $name ( sort { $a cmp $b } keys %{ $self->{_headers} } ) {
        my @headers      = @{ $self->{_headers}->{$name} };
        my $first        = shift @headers;
        my $encoded_name = URI::Escape::uri_escape($name);
        if ( defined $first ) {
            my $value         = $first->{value};
            my $encoded_value = URI::Escape::uri_escape($value);
            my $validated_merge =
              $self->_validate_request_header_merge( $first->{merge} );
            $script .= <<"_JS_";
    channel.setRequestHeader(decodeURIComponent("$encoded_name"), decodeURIComponent("$encoded_value"), $validated_merge);
_JS_
        }
        foreach my $value (@headers) {
            my $encoded_value = URI::Escape::uri_escape( $value->{value} );
            my $validated_merge =
              $self->_validate_request_header_merge( $value->{merge} );
            $script .= <<"_JS_";
    channel.setRequestHeader(decodeURIComponent("$encoded_name"), decodeURIComponent("$encoded_value"), $validated_merge);
_JS_
        }
    }
    foreach my $host ( sort { $a cmp $b } keys %{ $self->{_site_headers} } ) {
        my $encoded_host = URI::Escape::uri_escape($host);
        foreach my $name (
            sort { $a cmp $b }
            keys %{ $self->{_site_headers}->{$host} }
          )
        {
            my @headers      = @{ $self->{_site_headers}->{$host}->{$name} };
            my $first        = shift @headers;
            my $encoded_name = URI::Escape::uri_escape($name);
            if ( defined $first ) {
                my $encoded_value = URI::Escape::uri_escape( $first->{value} );
                my $validated_merge =
                  $self->_validate_request_header_merge( $first->{merge} );
                $script .= <<"_JS_";
    if (host === decodeURIComponent("$encoded_host")) {
      channel.setRequestHeader(decodeURIComponent("$encoded_name"), decodeURIComponent("$encoded_value"), $validated_merge);
    }
_JS_
            }
            foreach my $value (@headers) {
                my $encoded_value = URI::Escape::uri_escape( $value->{value} );
                my $validated_merge =
                  $self->_validate_request_header_merge( $value->{merge} );
                $script .= <<"_JS_";
    if (host === decodeURIComponent("$encoded_host")) {
      channel.setRequestHeader(decodeURIComponent("$encoded_name"), decodeURIComponent("$encoded_value"), $validated_merge);
    }
_JS_
            }
        }
    }
    $script .= <<'_JS_';
  }
};

PerlFirefoxMarionette.headers.register();
_JS_
    $script =~ s/[\r\n\t]+/ /smxg;
    $script =~ s/[ ]+/ /smxg;
    $self->script($script);
    $self->context('content');
    return;
}

sub is_selected {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
'is_selected method requires a Firefox::Marionette::Element parameter'
        );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:IsElementSelected'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response) ? 1 : 0;
}

sub _response_result_value {
    my ( $self, $response ) = @_;
    return $response->result()->{value};
}

sub is_enabled {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
'is_enabled method requires a Firefox::Marionette::Element parameter'
        );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:IsElementEnabled'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response) ? 1 : 0;
}

sub is_displayed {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
'is_displayed method requires a Firefox::Marionette::Element parameter'
        );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:IsElementDisplayed'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response) ? 1 : 0;
}

sub send_keys {
    my ( $self, $element, $text ) = @_;
    Carp::carp(
        '**** DEPRECATED METHOD - send_keys HAS BEEN REPLACED BY type ****');
    return $self->type( $element, $text );
}

sub type {
    my ( $self, $element, $text ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'type method requires a Firefox::Marionette::Element parameter');
    }
    my $message_id = $self->_new_message_id();
    my $parameters = { id => $element->uuid(), text => $text };
    if ( !$self->_is_new_sendkeys_okay() ) {
        $parameters->{value} = [ split //smx, $text ];
    }
    $self->_send_request(
        [
            _COMMAND(),                                   $message_id,
            $self->_command('WebDriver:ElementSendKeys'), $parameters
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub delete_session {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:DeleteSession') ]
    );
    my $response = $self->_get_response($message_id);
    delete $self->{session_id};
    return $self;
}

sub minimise {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id, $self->_command('WebDriver:MinimizeWindow')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub maximise {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id, $self->_command('WebDriver:MaximizeWindow')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub refresh {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:Refresh') ] );
    my $response = $self->_get_response($message_id);
    return $self;
}

my %_deprecated_commands = (
    'Marionette:Quit'                 => 'quitApplication',
    'Marionette:SetContext'           => 'setContext',
    'Marionette:GetContext'           => 'getContext',
    'Marionette:AcceptConnections'    => 'acceptConnections',
    'Marionette:GetScreenOrientation' => 'getScreenOrientation',
    'Marionette:SetScreenOrientation' => 'setScreenOrientation',
    'Addon:Install'                   => 'addon:install',
    'Addon:Uninstall'                 => 'addon:uninstall',
    'WebDriver:AcceptAlert'           => 'acceptDialog',
    'WebDriver:AcceptDialog'          => 'acceptDialog',
    'WebDriver:AddCookie'             => 'addCookie',
    'WebDriver:Back'                  => 'goBack',
    'WebDriver:CloseChromeWindow'     => 'closeChromeWindow',
    'WebDriver:CloseWindow'           => [
        {
            command      => 'closeWindow',
            before_major => _MAX_VERSION_FOR_ANCIENT_CMDS()
        },
        { command => 'close', before_major => _MAX_VERSION_FOR_NEW_CMDS() }
    ],
    'WebDriver:DeleteAllCookies' => 'deleteAllCookies',
    'WebDriver:DeleteCookie'     => 'deleteCookie',
    'WebDriver:DeleteSession'    => 'deleteSession',
    'WebDriver:DismissAlert'     => 'dismissDialog',
    'Marionette:GetWindowType'   => [
        {
            command      => 'getWindowType',
            before_major => _MAX_VERSION_FOR_NEW_CMDS(),
        },
    ],
    'WebDriver:DismissAlert'           => 'dismissDialog',
    'WebDriver:ElementClear'           => 'clearElement',
    'WebDriver:ElementClick'           => 'clickElement',
    'WebDriver:ElementSendKeys'        => 'sendKeysToElement',
    'WebDriver:ExecuteAsyncScript'     => 'executeAsyncScript',
    'WebDriver:ExecuteScript'          => 'executeScript',
    'WebDriver:FindElement'            => 'findElement',
    'WebDriver:FindElements'           => 'findElements',
    'WebDriver:Forward'                => 'goForward',
    'WebDriver:FullscreenWindow'       => 'fullscreen',
    'WebDriver:GetActiveElement'       => 'getActiveElement',
    'WebDriver:GetActiveFrame'         => 'getActiveFrame',
    'WebDriver:GetAlertText'           => 'getTextFromDialog',
    'WebDriver:GetCapabilities'        => 'getSessionCapabilities',
    'WebDriver:GetChromeWindowHandle'  => 'getChromeWindowHandle',
    'WebDriver:GetChromeWindowHandles' => 'getChromeWindowHandles',
    'WebDriver:GetCookies'             => [
        {
            command      => 'getAllCookies',
            before_major => _MAX_VERSION_FOR_ANCIENT_CMDS()
        },
        {
            command      => 'getCookies',
            before_major => _MAX_VERSION_FOR_NEW_CMDS()
        }
    ],
    'WebDriver:GetCurrentChromeWindowHandle' =>
      [ { command => 'getChromeWindowHandle', before_major => 60 } ],
    'WebDriver:GetCurrentURL' => [
        {
            command      => 'getUrl',
            before_major => _MAX_VERSION_FOR_ANCIENT_CMDS()
        },
        {
            command      => 'getCurrentUrl',
            before_major => _MAX_VERSION_FOR_NEW_CMDS()
        }
    ],
    'WebDriver:GetElementAttribute' => 'getElementAttribute',
    'WebDriver:GetElementCSSValue'  => 'getElementValueOfCssProperty',
    'WebDriver:GetElementProperty'  => 'getElementProperty',
    'WebDriver:GetElementRect'      => 'getElementRect',
    'WebDriver:GetElementTagName'   => 'getElementTagName',
    'WebDriver:GetElementText'      => 'getElementText',
    'WebDriver:GetPageSource'       => 'getPageSource',
    'WebDriver:GetTimeouts'         => 'getTimeouts',
    'WebDriver:GetTitle'            => 'getTitle',
    'WebDriver:GetWindowHandle'     => [
        {
            command      => 'getWindow',
            before_major => _MAX_VERSION_FOR_ANCIENT_CMDS()
        },
        {
            command      => 'getWindowHandle',
            before_major => _MAX_VERSION_FOR_NEW_CMDS()
        }
    ],
    'WebDriver:GetWindowHandles' => [
        {
            command      => 'getWindows',
            before_major => _MAX_VERSION_FOR_ANCIENT_CMDS()
        },
        {
            command      => 'getWindowHandles',
            before_major => _MAX_VERSION_FOR_NEW_CMDS()
        }
    ],
    'WebDriver:GetWindowRect' =>
      [ { command => 'getWindowSize', before_major => 60 } ],
    'WebDriver:IsElementDisplayed' => 'isElementDisplayed',
    'WebDriver:IsElementEnabled'   => 'isElementEnabled',
    'WebDriver:IsElementSelected'  => 'isElementSelected',
    'WebDriver:MaximizeWindow'     => 'maximizeWindow',
    'WebDriver:MinimizeWindow'     => 'minimizeWindow',
    'WebDriver:Navigate'           => [
        { command => 'goUrl', before_major => _MAX_VERSION_FOR_ANCIENT_CMDS() },
        { command => 'get',   before_major => _MAX_VERSION_FOR_NEW_CMDS() }
    ],
    'WebDriver:NewSession'     => 'newSession',
    'WebDriver:PerformActions' => 'performActions',
    'WebDriver:Refresh'        => 'refresh',
    'WebDriver:ReleaseActions' => 'releaseActions',
    'WebDriver:SendAlertText'  => 'sendKeysToDialog',
    'WebDriver:SetTimeouts'    => 'setTimeouts',
    'WebDriver:SetWindowRect'  =>
      [ { command => 'setWindowSize', before_major => 60 } ],
    'WebDriver:SwitchToFrame'       => 'switchToFrame',
    'WebDriver:SwitchToParentFrame' => 'switchToParentFrame',
    'WebDriver:SwitchToShadowRoot'  => 'switchToShadowRoot',
    'WebDriver:SwitchToWindow'      => 'switchToWindow',
    'WebDriver:TakeScreenshot'      => [
        {
            command      => 'screenShot',
            before_major => _MAX_VERSION_FOR_ANCIENT_CMDS()
        },
        {
            command      => 'takeScreenshot',
            before_major => _MAX_VERSION_FOR_NEW_CMDS()
        }
    ],
);

sub _command {
    my ( $self, $command ) = @_;
    if ( defined $self->browser_version() ) {
        my ( $major, $minor, $patch ) = split /[.]/smx,
          $self->browser_version();
        if ( $_deprecated_commands{$command} ) {
            if ( ref $_deprecated_commands{$command} ) {
                foreach my $command ( @{ $_deprecated_commands{$command} } ) {
                    if ( $major < $command->{before_major} ) {
                        return $command->{command};
                    }
                }
            }
            elsif ( $major < _MAX_VERSION_FOR_NEW_CMDS() ) {

                return $_deprecated_commands{$command};
            }
        }
    }
    return $command;
}

sub capabilities {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetCapabilities')
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        return $self->_create_capabilities(
            $response->result()->{capabilities} );
    }
    else {
        return $self->_create_capabilities( $response->result()->{value} );
    }

}

sub delete_cookies {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:DeleteAllCookies')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub delete_cookie {
    my ( $self, $name ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:DeleteCookie'), { name => $name }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub cookies {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:GetCookies') ] );
    my $response = $self->_get_response($message_id);
    my @cookies;
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        @cookies = @{ $response->result() };
    }
    else {
        @cookies = @{ $response->result()->{value} };
    }
    return map {
        Firefox::Marionette::Cookie->new(
            http_only => $_->{httpOnly} ? 1 : 0,
            secure    => $_->{secure}   ? 1 : 0,
            domain    => $_->{domain},
            path      => $_->{path},
            value     => $_->{value},
            expiry    => $_->{expiry},
            name      => $_->{name},
            same_site => $_->{sameSite},
        )
    } @cookies;
}

sub tag_name {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'tag_name method requires a Firefox::Marionette::Element parameter'
        );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetElementTagName'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub window_rect {
    my ( $self, $new ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:GetWindowRect') ]
    );
    my $response = $self->_get_response($message_id);
    my $result   = $response->result();
    if ( $result->{value} ) {
        $result = $result->{value};
    }
    my $old = Firefox::Marionette::Window::Rect->new(
        pos_x  => $result->{x},
        pos_y  => $result->{y},
        width  => $result->{width},
        height => $result->{height},
        wstate => $result->{state},
    );
    if ( defined $new ) {
        $message_id = $self->_new_message_id();
        $self->_send_request(
            [
                _COMMAND(),
                $message_id,
                $self->_command('WebDriver:SetWindowRect'),
                {
                    x      => $new->pos_x(),
                    y      => $new->pos_y(),
                    width  => $new->width(),
                    height => $new->height()
                }
            ]
        );
        $self->_get_response($message_id);
    }
    return $old;
}

sub rect {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'rect method requires a Firefox::Marionette::Element parameter');
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetElementRect'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    my $result   = $response->result();
    if ( $result->{value} ) {
        $result = $result->{value};
    }
    return Firefox::Marionette::Element::Rect->new(
        pos_x  => $result->{x},
        pos_y  => $result->{y},
        width  => $result->{width},
        height => $result->{height},
    );
}

sub text {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'text method requires a Firefox::Marionette::Element parameter');
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetElementText'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub clear {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'clear method requires a Firefox::Marionette::Element parameter');
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:ElementClear'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub click {
    my ( $self, $element ) = @_;
    if (
        !(
               ( ref $element )
            && ( ref $element eq 'Firefox::Marionette::Element' )
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'click method requires a Firefox::Marionette::Element parameter');
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:ElementClick'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub timeouts {
    my ( $self, $new ) = @_;
    my $old;
    if ( $self->{_no_timeouts_command} ) {
        if ( !defined $self->{_no_timeouts_command}->{page_load} ) {
            $self->{_no_timeouts_command} = $new;
        }
        $old = $self->{_no_timeouts_command};
    }
    else {
        my $message_id = $self->_new_message_id();
        $self->_send_request(
            [
                _COMMAND(), $message_id,
                $self->_command('WebDriver:GetTimeouts')
            ]
        );
        my $response = $self->_get_response($message_id);
        $old = Firefox::Marionette::Timeouts->new(
            page_load =>
              $response->result()->{ $self->{_page_load_timeouts_key} },
            script   => $response->result()->{script},
            implicit => $response->result()->{implicit}
        );
    }
    if ( defined $new ) {
        if ( $self->{_no_timeouts_command} ) {
            my $message_id = $self->_new_message_id();
            $self->_send_request(
                [
                    _COMMAND(),
                    $message_id,
                    'timeouts',
                    {
                        type => 'implicit',
                        ms   => $new->implicit(),
                    }
                ]
            );
            $self->_get_response($message_id);
            $message_id = $self->_new_message_id();
            $self->_send_request(
                [
                    _COMMAND(),
                    $message_id,
                    'timeouts',
                    {
                        type => 'script',
                        ms   => $new->script(),
                    }
                ]
            );
            $self->_get_response($message_id);
            $message_id = $self->_new_message_id();
            $self->_send_request(
                [
                    _COMMAND(),
                    $message_id,
                    'timeouts',
                    {
                        type => 'default',
                        ms   => $new->page_load(),
                    }
                ]
            );
            $self->_get_response($message_id);
            $self->{_no_timeouts_command} = $new;
        }
        else {
            my $message_id = $self->_new_message_id();
            $self->_send_request(
                [
                    _COMMAND(),
                    $message_id,
                    $self->_command('WebDriver:SetTimeouts'),
                    {
                        $self->{_page_load_timeouts_key} => $new->page_load(),
                        script                           => $new->script(),
                        implicit                         => $new->implicit()
                    }
                ]
            );
            $self->_get_response($message_id);
        }
    }
    return $old;
}

sub active_element {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetActiveElement')
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( ref $self->_response_result_value($response) ) {
        return Firefox::Marionette::Element->new( $self,
            %{ $self->_response_result_value($response) } );
    }
    else {
        return Firefox::Marionette::Element->new( $self,
            ELEMENT => $self->_response_result_value($response) );
    }
}

sub uri {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:GetCurrentURL') ]
    );
    my $response = $self->_get_response($message_id);
    return URI->new( $self->_response_result_value($response) );
}

sub full_screen {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:FullscreenWindow')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub dismiss_alert {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:DismissAlert') ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub send_alert_text {
    my ( $self, $text ) = @_;
    my $message_id = $self->_new_message_id();
    my $parameters = { text => $text };
    if ( !$self->_is_new_sendkeys_okay() ) {
        $parameters->{value} = [ split //smx, $text ];
    }
    $self->_send_request(
        [
            _COMMAND(),                                 $message_id,
            $self->_command('WebDriver:SendAlertText'), $parameters
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub accept_alert {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:AcceptAlert') ] );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub accept_dialog {
    my ($self) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - using accept_dialog() HAS BEEN REPLACED BY accept_alert ****'
    );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:AcceptDialog') ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub alert_text {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:GetAlertText') ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

my %_pdf_sizes = (

    #    '4A0' => { width => 168.2, height => 237.8 },
    #    '2A0' => { width => 118.9, height => 168.2 },
    #    A9    => { width => 3.7,  height => 5.2 },
    #    A10   => { width => 2.6,  height => 3.7 },
    #    B0    => { width => 100,  height => 141.4 },
    A1           => { width => 59.4, height => 84.1 },
    A2           => { width => 42,   height => 59.4 },
    A3           => { width => 29.7, height => 42 },
    A4           => { width => 21,   height => 29.7 },
    A5           => { width => 14.8, height => 21 },
    A6           => { width => 10.5, height => 14.8 },
    A7           => { width => 7.4,  height => 10.5 },
    A8           => { width => 5.2,  height => 7.4 },
    B1           => { width => 70.7, height => 100 },
    B2           => { width => 50,   height => 70.7 },
    B3           => { width => 35.3, height => 50 },
    B4           => { width => 25,   height => 35.3 },
    B5           => { width => 17.6, height => 25 },
    B6           => { width => 12.5, height => 17.6 },
    B7           => { width => 8.8,  height => 12.5 },
    B8           => { width => 6.2,  height => 8.8 },
    HALF_LETTER  => { width => 14,   height => 21.6 },
    LETTER       => { width => 21.6, height => 27.9 },
    LEGAL        => { width => 21.6, height => 35.6 },
    JUNIOR_LEGAL => { width => 12.7, height => 20.3 },
    LEDGER       => { width => 12.7, height => 20.3 },
);

sub paper_sizes {
    my @keys = sort { $a cmp $b } keys %_pdf_sizes;
    return @keys;
}

sub _map_deprecated_pdf_parameters {
    my ( $self, %parameters ) = @_;
    my %mapping = (
        shrink_to_fit    => 'shrinkToFit',
        print_background => 'printBackground',
    );
    foreach my $from ( sort { $a cmp $b } keys %mapping ) {
        my $to = $mapping{$from};
        if ( defined $parameters{$to} ) {
            Carp::carp(
"**** DEPRECATED PARAMETER - using $to as a parameter for the pdf(...) method HAS BEEN REPLACED BY the $from parameter ****"
            );
        }
        elsif ( defined $parameters{$from} ) {
            $parameters{$to} = $parameters{$from};
            delete $parameters{$from};
        }
    }
    foreach my $key ( sort { $a cmp $b } keys %parameters ) {
        next if ( $key eq 'landscape' );
        next if ( $key eq 'shrinkToFit' );
        next if ( $key eq 'printBackground' );
        next if ( $key eq 'margin' );
        next if ( $key eq 'page' );
        next if ( $key eq 'size' );
        next if ( $key eq 'raw' );
        Firefox::Marionette::Exception->throw(
            "Unknown key $key for the pdf method");
    }
    return %parameters;
}

sub _initialise_pdf_parameters {
    my ( $self, %parameters ) = @_;
    %parameters = $self->_map_deprecated_pdf_parameters(%parameters);
    foreach my $key (qw(landscape shrinkToFit printBackground)) {
        if ( defined $parameters{$key} ) {
            $parameters{$key} = $parameters{$key} ? \1 : \0;
        }
    }
    if ( defined $parameters{page} ) {
        foreach my $key ( sort { $a cmp $b } keys %{ $parameters{page} } ) {
            next if ( $key eq 'width' );
            next if ( $key eq 'height' );
            Firefox::Marionette::Exception->throw(
                "Unknown key $key for the page parameter");
        }
    }
    if ( defined $parameters{margin} ) {
        foreach my $key ( sort { $a cmp $b } keys %{ $parameters{margin} } ) {
            next if ( $key eq 'top' );
            next if ( $key eq 'left' );
            next if ( $key eq 'bottom' );
            next if ( $key eq 'right' );
            Firefox::Marionette::Exception->throw(
                "Unknown key $key for the margin parameter");
        }
    }
    if ( my $size = delete $parameters{size} ) {
        $size =~ s/[ ]/_/smxg;
        if ( defined( my $instance = $_pdf_sizes{ uc $size } ) ) {
            $parameters{page}{width}  = $instance->{width};
            $parameters{page}{height} = $instance->{height};
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Page size of $size is unknown");
        }
    }
    return %parameters;
}

sub pdf {
    my ( $self, %parameters ) = @_;
    %parameters = $self->_initialise_pdf_parameters(%parameters);
    my $raw        = delete $parameters{raw};
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),                         $message_id,
            $self->_command('WebDriver:Print'), \%parameters
        ]
    );
    my $response = $self->_get_response($message_id);
    if ($raw) {
        my $content = $self->_response_result_value($response);
        return MIME::Base64::decode_base64($content);
    }
    else {
        my $handle = File::Temp::tempfile(
            File::Spec->catfile(
                File::Spec->tmpdir(), 'firefox_marionette_print_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
        binmode $handle;
        my $content = $self->_response_result_value($response);
        $handle->print( MIME::Base64::decode_base64($content) )
          or Firefox::Marionette::Exception->throw(
            "Failed to write to temporary file:$EXTENDED_OS_ERROR");
        $handle->seek( 0, Fcntl::SEEK_SET() )
          or Firefox::Marionette::Exception->throw(
            "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
        return $handle;
    }
}

sub selfie {
    my ( $self, $element, @remaining ) = @_;
    my $message_id = $self->_new_message_id();
    my $parameters = {};
    my %extra;
    if (   ( ref $element )
        && ( ref $element eq 'Firefox::Marionette::Element' ) )
    {
        $parameters = { id => $element->uuid() };
        %extra      = @remaining;
    }
    elsif (( defined $element )
        && ( not( ref $element ) )
        && ( ( scalar @remaining ) % 2 ) )
    {
        %extra   = ( $element, @remaining );
        $element = undef;
    }
    if ( $extra{highlights} ) {
        foreach my $highlight ( @{ $extra{highlights} } ) {
            push @{ $parameters->{highlights} }, $highlight->uuid();
        }
    }
    foreach my $key (qw(hash full scroll)) {
        if ( $extra{$key} ) {
            $parameters->{$key} = \1;
        }
    }
    $self->_send_request(
        [
            _COMMAND(),                                  $message_id,
            $self->_command('WebDriver:TakeScreenshot'), $parameters
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( $extra{hash} ) {
        return $self->_response_result_value($response);
    }
    elsif ( $extra{raw} ) {
        my $content = $self->_response_result_value($response);
        $content =~ s/^data:image\/png;base64,//smx;
        return MIME::Base64::decode_base64($content);
    }
    else {
        my $handle = File::Temp::tempfile(
            File::Spec->catfile(
                File::Spec->tmpdir(), 'firefox_marionette_selfie_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
        binmode $handle;
        my $content = $self->_response_result_value($response);
        $content =~ s/^data:image\/png;base64,//smx;
        $handle->print( MIME::Base64::decode_base64($content) )
          or Firefox::Marionette::Exception->throw(
            "Failed to write to temporary file:$EXTENDED_OS_ERROR");
        $handle->seek( 0, Fcntl::SEEK_SET() )
          or Firefox::Marionette::Exception->throw(
            "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
        return $handle;
    }
}

sub current_chrome_window_handle {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetCurrentChromeWindowHandle')
        ]
    );
    my $response = $self->_get_response($message_id);
    if (   ( defined $response->{result}->{ok} )
        && ( $response->{result}->{ok} ) )
    {
        $response = $self->_get_response($message_id);
    }
    return $self->_response_result_value($response);
}

sub chrome_window_handle {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetChromeWindowHandle')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub chrome_window_handles {
    my ( $self, $element ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetChromeWindowHandles')
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        return @{ $response->result() };
    }
    else {
        return @{ $response->result()->{value} };
    }
}

sub window_handle {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetWindowHandle')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub window_handles {
    my ( $self, $element ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetWindowHandles')
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        return @{ $response->result() };
    }
    else {
        return @{ $response->result()->{value} };
    }
}

sub new_window {
    my ( $self, %parameters ) = @_;

    foreach my $key (qw(focus private)) {
        if ( defined $parameters{$key} ) {
            $parameters{$key} = $parameters{$key} ? \1 : \0;
        }
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:NewWindow'), {%parameters}
        ]
    );
    my $response = $self->_get_response($message_id);
    return $response->result()->{handle};
}

sub close_current_chrome_window_handle {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:CloseChromeWindow')
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( ref $response->result() eq 'HASH' ) {
        return ( $self->_response_result_value($response) );
    }
    else {
        return @{ $response->result() };
    }
}

sub close_current_window_handle {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:CloseWindow') ] );
    my $response = $self->_get_response($message_id);
    if ( ref $response->result() eq 'HASH' ) {
        return ( $response->result() );
    }
    else {
        return @{ $response->result() };
    }
}

sub css {
    my ( $self, $element, $property_name ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebDriver:GetElementCSSValue'),
            { id => $element->uuid(), propertyName => $property_name }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub property {
    my ( $self, $element, $name ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebDriver:GetElementProperty'),
            { id => $element->uuid(), name => $name }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub attribute {
    my ( $self, $element, $name ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetElementAttribute'),
            { id => $element->uuid(), name => $name }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub find_element {
    my ( $self, $value, $using ) = @_;
    Carp::carp(
        '**** DEPRECATED METHOD - find_element HAS BEEN REPLACED BY find ****');
    return $self->find( $value, $using );
}

sub find {
    my ( $self, $value, $using, $from ) = @_;
    return $self->_find( $value, $using, $from );
}

sub find_id {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'id', $from );
}

sub find_name {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'name', $from );
}

sub find_tag {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'tag name', $from );
}

sub find_class {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'class name', $from );
}

sub find_selector {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'css selector', $from );
}

sub find_link {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'link text', $from );
}

sub find_partial {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'partial link text', $from );
}

sub find_by_id {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
        '**** DEPRECATED METHOD - find_by_id HAS BEEN REPLACED BY find_id ****'
    );
    return $self->find_id( $value, $from );
}

sub find_by_name {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - find_by_name HAS BEEN REPLACED BY find_name ****'
    );
    return $self->find_name( $value, $from );
}

sub find_by_tag {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - find_by_tag HAS BEEN REPLACED BY find_tag ****'
    );
    return $self->find_tag( $value, $from );
}

sub find_by_class {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - find_by_class HAS BEEN REPLACED BY find_class ****'
    );
    return $self->find_class( $value, $from );
}

sub find_by_selector {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - find_by_selector HAS BEEN REPLACED BY find_selector ****'
    );
    return $self->find_selector( $value, $from );
}

sub find_by_link {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - find_by_link HAS BEEN REPLACED BY find_link ****'
    );
    return $self->find_link( $value, $from );
}

sub find_by_partial {
    my ( $self, $value, $from ) = @_;
    Carp::carp(
'**** DEPRECATED METHOD - find_by_partial HAS BEEN REPLACED BY find_partial ****'
    );
    return $self->find_partial( $value, $from );
}

sub _find {
    my ( $self, $value, $using, $from ) = @_;
    $using ||= 'xpath';
    my $message_id = $self->_new_message_id();
    my $parameters = { using => $using, value => $value };
    if ( defined $from ) {
        if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() )
        {
            $parameters->{element} = $from->uuid();
        }
        else {
            $parameters->{ELEMENT} = $from->uuid();
        }
    }
    my $command =
      wantarray ? 'WebDriver:FindElements' : 'WebDriver:FindElement';
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command($command), $parameters, ] );
    my $response =
      $self->_get_response( $message_id, { using => $using, value => $value } );
    if (wantarray) {
        if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() )
        {
            return
              map { Firefox::Marionette::Element->new( $self, %{$_} ) }
              @{ $response->result() };
        }
        elsif (( ref $self->_response_result_value($response) )
            && ( ( ref $self->_response_result_value($response) ) eq 'ARRAY' )
            && ( ref $self->_response_result_value($response)->[0] )
            && ( ( ref $self->_response_result_value($response)->[0] ) eq
                'HASH' ) )
        {
            return
              map { Firefox::Marionette::Element->new( $self, %{$_} ) }
              @{ $self->_response_result_value($response) };
        }
        else {
            return
              map { Firefox::Marionette::Element->new( $self, ELEMENT => $_ ) }
              @{ $self->_response_result_value($response) };
        }
    }
    else {
        if (
            (
                $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3()
            )
            || ( $self->{_initial_packet_size} != _OLD_INITIAL_PACKET_SIZE() )
          )
        {
            return Firefox::Marionette::Element->new( $self,
                %{ $self->_response_result_value($response) } );
        }
        else {
            return Firefox::Marionette::Element->new( $self,
                ELEMENT => $self->_response_result_value($response) );
        }
    }
}

sub active_frame {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id, $self->_command('WebDriver:GetActiveFrame')
        ]
    );
    my $response = $self->_get_response($message_id);
    if ( defined $self->_response_result_value($response) ) {
        if ( ref $self->_response_result_value($response) ) {
            return Firefox::Marionette::Element->new( $self,
                %{ $self->_response_result_value($response) } );
        }
        else {
            return Firefox::Marionette::Element->new( $self,
                ELEMENT => $self->_response_result_value($response) );
        }
    }
    else {
        return;
    }
}

sub title {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:GetTitle') ] );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub quit {
    my ( $self, $flags ) = @_;
    if ( !$self->alive() ) {
        my $socket = delete $self->{_socket};
        if ($socket) {
            close $socket
              or Firefox::Marionette::Exception->throw(
                "Failed to close socket to firefox:$EXTENDED_OS_ERROR");
        }
        $self->_terminate_xvfb();
    }
    elsif ( $self->_socket() ) {
        if ( $self->_session_id() ) {
            $self->_quit_over_marionette($flags);
            delete $self->{session_id};
        }
        $self->_terminate_process();
    }
    if ( !$self->_reconnected() ) {
        if ( $self->{_ssh_local_directory} ) {
            $self->{_ssh_local_directory}->unlink_on_destroy(1);
        }
        elsif ( defined $self->{_root_directory} ) {
            $self->{_root_directory}->unlink_on_destroy(1);
        }
    }
    return $self->child_error();
}

sub _quit_over_marionette {
    my ( $self, $flags ) = @_;
    $flags ||=
      ['eAttemptQuit'];    # ["eConsiderQuit", "eAttemptQuit", "eForceQuit"]
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('Marionette:Quit'), { flags => $flags }
        ]
    );
    my $response = $self->_get_response($message_id);
    my $socket   = delete $self->{_socket};
    if ( $OSNAME eq 'MSWin32' ) {
        if ( defined $self->{_win32_ssh_process} ) {
            $self->{_win32_ssh_process}->Wait( Win32::Process::INFINITE() );
            $self->_reap();
        }
        if ( defined $self->{_win32_firefox_process} ) {
            $self->{_win32_firefox_process}->Wait( Win32::Process::INFINITE() );
            $self->_reap();
        }
    }
    elsif ( ( $OSNAME eq 'MSWin32' ) && ( !$self->_ssh() ) ) {
        $self->{_win32_firefox_process}->Wait( Win32::Process::INFINITE() );
        $self->_reap();
    }
    else {
        if (
            !$self->_is_firefox_major_version_at_least(
                _MIN_VERSION_FOR_MODERN_EXIT()
            )
          )
        {
            close $socket
              or Firefox::Marionette::Exception->throw(
                "Failed to close socket to firefox:$EXTENDED_OS_ERROR");
            $socket = undef;
        }
        elsif ( $self->_ssh() ) {
            close $socket
              or Firefox::Marionette::Exception->throw(
                "Failed to close socket to firefox:$EXTENDED_OS_ERROR");
            $socket = undef;
        }
        $self->_wait_for_firefox_to_exit();
    }
    if ( defined $socket ) {
        close $socket
          or Firefox::Marionette::Exception->throw(
            "Failed to close socket to firefox:$EXTENDED_OS_ERROR");
    }
    return;
}

sub _sandbox_regex {
    my ($self) = @_;
    return qr/security[.]sandbox[.](\w+)[.]tempDirSuffix/smx;
}

sub _sandbox_prefix {
    my ($self) = @_;
    return 'Temp-';
}

sub _wait_for_firefox_to_exit {
    my ($self) = @_;
    if ( $self->_ssh() ) {
        if ( $self->_reconnected() ) {
            while ( $self->_remote_process_running( $self->_firefox_pid() ) ) {
                sleep 1;
            }
        }
        else {
            while ( kill 0, $self->_local_ssh_pid() ) {
                sleep 1;
                $self->_reap();
            }
        }
    }
    elsif ( $OSNAME eq 'MSWin32' ) {
        $self->{_win32_firefox_process}->GetExitCode( my $exit_code );
        while ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
            sleep 1;
            $exit_code = $self->{_win32_firefox_process}->Kill(1);
        }

    }
    else {
        while ( kill 0, $self->_firefox_pid() ) {
            sleep 1;
            $self->_reap();
        }
    }
    return;
}

sub _get_remote_root_directory {
    my ($self) = @_;
    $self->_initialise_remote_uname();
    my $original_tmp_directory;
    {
        local %ENV = %ENV;
        delete $ENV{TMPDIR};
        delete $ENV{TMP};
        $original_tmp_directory =
             $self->_get_remote_environment_variable_via_ssh('TMPDIR')
          || $self->_get_remote_environment_variable_via_ssh('TMP')
          || '/tmp';
        $original_tmp_directory =~ s/\/$//smx;    # remove trailing / for darwin
        $self->{_original_remote_tmp_directory} = $original_tmp_directory;
    }
    my $name = File::Temp::mktemp('firefox_marionette_remote_XXXXXXXXXXX');
    my $proposed_tmp_directory =
      $self->_remote_catfile( $original_tmp_directory, $name );
    local $ENV{TMPDIR} = $proposed_tmp_directory;
    my $new_tmp_dir = $self->_get_remote_environment_variable_via_ssh('TMPDIR');
    my $remote_root_directory;

    if (   ( defined $new_tmp_dir )
        && ( $new_tmp_dir eq $proposed_tmp_directory ) )
    {
        $remote_root_directory = $self->_make_remote_directory($new_tmp_dir);
    }
    else {
        $remote_root_directory = $self->_make_remote_directory(
            $self->_remote_catfile( $original_tmp_directory, $name ) );
    }
    return $remote_root_directory;
}

sub _get_remote_environment_command {
    my ( $self, $name ) = @_;
    my $command;
    if ( ( $self->_remote_uname() ) && ( $self->_remote_uname() eq 'MSWin32' ) )
    {
        $command = q[echo ] . $name . q[="%] . $name . q[%"];
    }
    else {
        $command =
          'echo "' . $name . q[=] . q[\\] . q["] . q[$] . $name . q[\\] . q[""];
    }
    return $command;
}

sub _get_remote_environment_variable_via_ssh {
    my ( $self, $name ) = @_;
    my $value;
    my $output = $self->_execute_via_ssh( {},
        $self->_get_remote_environment_command($name) );
    if ( defined $output ) {
        foreach my $line ( split /\r?\n/smx, $output ) {
            if ( $line eq "$name=\"%$name%\"" ) {
            }
            elsif ( $line =~ /^$name="([^"]*)"$/smx ) {
                $value = $1;
            }
        }
    }
    return $value;
}

sub _cleanup_remote_filesystem {
    my ($self) = @_;
    if (   ( my $ssh = $self->_ssh() )
        && ( defined $self->{_root_directory} ) )
    {
        my $binary     = 'rm';
        my @parameters = ('-Rf');
        if ( $self->_remote_uname() eq 'MSWin32' ) {
            $binary     = 'rmdir';
            @parameters = ( '/S', '/Q' );
        }
        my @remote_directories = ( $self->{_root_directory} );
        if ( $self->{_original_remote_tmp_directory} ) {
            foreach my $sandbox ( sort { $a cmp $b } keys %{ $ssh->{sandbox} } )
            {
                push @remote_directories,
                  $self->_remote_catfile(
                    $self->{_original_remote_tmp_directory},
                    $self->_sandbox_prefix() . $ssh->{sandbox}->{$sandbox} );
            }
        }
        if ( $self->_remote_uname() eq 'MSWin32' ) {
            foreach my $remote_directory (@remote_directories) {
                $self->_system(
                    'ssh',
                    $self->_ssh_parameters(),
                    $self->_ssh_address(),
                    (
                        join q[ ], 'if',
                        'exist',   $remote_directory,
                        'rmdir',   '/S',
                        '/Q',      $remote_directory
                    )
                );
            }
        }
        else {
            $self->_system( 'ssh', $self->_ssh_parameters(),
                $self->_ssh_address(),
                ( join q[ ], $binary, @parameters, @remote_directories ) );
        }
    }
    return;
}

sub _terminate_master_control_via_ssh {
    my ($self) = @_;
    my $path = $self->_control_path();
    if ( ( defined $path ) && ( -e $path ) ) {
    }
    elsif ( ( !defined $path ) || ( $OS_ERROR == POSIX::ENOENT() ) ) {
        return;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to stat '$path':$EXTENDED_OS_ERROR");
    }
    $self->_system( 'ssh', $self->_ssh_parameters(),
        '-O', 'exit', $self->_ssh_address() );
    return;
}

sub _terminate_process_via_ssh {
    my ($self) = @_;
    if ( $self->_reconnected() ) {
    }
    else {
        my $term_signal = $self->_signal_number('TERM')
          ;    # https://support.mozilla.org/en-US/questions/752748
        if ( $term_signal > 0 ) {
            my $count = 0;
            while (( $count < _NUMBER_OF_TERM_ATTEMPTS() )
                && ( defined $self->_local_ssh_pid() )
                && ( kill $term_signal, $self->_local_ssh_pid() ) )
            {
                $count += 1;
                sleep 1;
                $self->_reap();
            }
        }
        my $kill_signal = $self->_signal_number('KILL');   # no more mr nice guy
        if ( ( $kill_signal > 0 ) && ( defined $self->_local_ssh_pid() ) ) {
            while ( kill $kill_signal, $self->_local_ssh_pid() ) {
                sleep 1;
                $self->_reap();
            }
        }
    }
    return;
}

sub _terminate_local_non_win32_process {
    my ($self) = @_;
    my $term_signal = $self->_signal_number('TERM')
      ;    # https://support.mozilla.org/en-US/questions/752748
    if ( $term_signal > 0 ) {
        my $count = 0;
        while (( $count < _NUMBER_OF_TERM_ATTEMPTS() )
            && ( kill $term_signal, $self->_firefox_pid() ) )
        {
            $count += 1;
            sleep 1;
            $self->_reap();
        }
    }
    my $kill_signal = $self->_signal_number('KILL');    # no more mr nice guy
    if ( $kill_signal > 0 ) {
        while ( kill $kill_signal, $self->_firefox_pid() ) {
            sleep 1;
            $self->_reap();
        }
    }
    return;
}

sub _terminate_local_win32_process {
    my ($self) = @_;
    if ( $self->{_win32_firefox_process} ) {
        $self->{_win32_firefox_process}->Kill(1);
        sleep 1;
        $self->{_win32_firefox_process}->GetExitCode( my $exit_code );
        while ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
            $self->{_win32_firefox_process}->Kill(1);
            sleep 1;
            $exit_code = $self->{_win32_firefox_process}->Kill(1);
        }
        $self->_reap();
    }
    if ( $self->{_win32_ssh_process} ) {
        $self->{_win32_ssh_process}->Kill(1);
        sleep 1;
        $self->{_win32_ssh_process}->GetExitCode( my $exit_code );
        while ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
            $self->{_win32_ssh_process}->Kill(1);
            sleep 1;
            $exit_code = $self->{_win32_ssh_process}->Kill(1);
        }
        $self->_reap();
    }
    foreach my $process ( @{ $self->{_other_win32_ssh_processes} } ) {
        $process->Kill(1);
        sleep 1;
        $process->GetExitCode( my $exit_code );
        while ( $exit_code == Win32::Process::STILL_ACTIVE() ) {
            $process->Kill(1);
            sleep 1;
            $exit_code = $process->Kill(1);
        }
        $self->_reap();
    }
    return;
}

sub _terminate_process {
    my ($self) = @_;
    if ( $OSNAME eq 'MSWin32' ) {
        $self->_terminate_local_win32_process();
    }
    elsif ( my $ssh = $self->_ssh() ) {
        $self->_terminate_process_via_ssh();
    }
    elsif ( ( $self->_firefox_pid() ) && ( kill 0, $self->_firefox_pid() ) ) {
        $self->_terminate_local_non_win32_process();
    }
    $self->_terminate_xvfb();
    return;
}

sub _terminate_xvfb {
    my ($self) = @_;
    if ( my $pid = $self->xvfb() ) {
        my $int_signal = $self->_signal_number('INT');
        while ( kill 0, $pid ) {
            kill $int_signal, $pid;
            sleep 1;
            $self->_reap();
        }
    }
    return;
}

sub context {
    my ( $self, $new ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('Marionette:GetContext') ] );
    my $response;
    eval { $response = $self->_get_response($message_id); } or do {
        Carp::carp( 'Retrieving context is not supported for Firefox '
              . $self->browser_version() . q[:]
              . $EVAL_ERROR );
    };
    my $context;
    if ( defined $response ) {
        $context =
          $self->_response_result_value($response);    # 'content' or 'chrome'
    }
    else {
        $context = $self->{'_context'} || 'content';
    }
    $self->{'_context'} = $context;
    if ( defined $new ) {
        $message_id = $self->_new_message_id();
        $self->_send_request(
            [
                _COMMAND(), $message_id,
                $self->_command('Marionette:SetContext'), { value => $new }
            ]
        );
        $response = $self->_get_response($message_id);
        $self->{'_context'} = $new;
    }
    return $context;
}

sub accept_connections {
    my ( $self, $new ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('Marionette:AcceptConnections'),
            { value => $new ? \1 : \0 }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub async_script {
    my ( $self, $script, %parameters ) = @_;
    delete $parameters{script};
    $parameters{args} ||= [];
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:ExecuteAsyncScript'),
            { script => $script, %parameters }
        ]
    );
    return $self;
}

sub interactive {
    my ($self) = @_;
    if ( $self->loaded() ) {
        return 1;
    }
    else {
        return $self->script(
'if (document.readyState === "interactive") { return 1; } else { return 0 }'
        );
    }
}

sub loaded {
    my ($self) = @_;
    return $self->script(
'if (document.readyState === "complete") { return 1; } else { return 0 }'
    );
}

sub _script_parameters {
    my ( $self, %parameters ) = @_;
    delete $parameters{script};
    $parameters{args} ||= [];
    my %mapping = (
        timeout => 'scriptTimeout',
        new     => 'newSandbox',
    );
    foreach my $from ( sort { $a cmp $b } keys %mapping ) {
        my $to = $mapping{$from};
        if ( defined $parameters{$to} ) {
            Carp::carp(
"**** DEPRECATED PARAMETER - using $to as a parameter for the script(...) method HAS BEEN REPLACED BY the $from parameter ****"
            );
        }
        elsif ( defined $parameters{$from} ) {
            $parameters{$to} = $parameters{$from};
            delete $parameters{$from};
        }
    }
    foreach my $key (qw(newSandbox)) {
        if ( defined $parameters{$key} ) {
            $parameters{$key} = $parameters{$key} ? \1 : \0;
        }
    }
    return %parameters;
}

sub script {
    my ( $self, $script, %parameters ) = @_;
    %parameters = $self->_script_parameters(%parameters);
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:ExecuteScript'),
            { script => $script, value => $script, %parameters }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub json {
    my ($self) = @_;
    my $content = $self->strip();
    return JSON::decode_json($content);
}

sub strip {
    my ($self)       = @_;
    my $content      = $self->html();
    my $head_regex   = qr/<head><link[^>]+><\/head>/smx;
    my $script_regex = qr/(?:<script[^>]+><\/script>)?/smx;
    my $header       = qr/<html[^>]*>$script_regex$head_regex<body><pre>/smx;
    my $footer       = qr/<\/pre><\/body><\/html>/smx;
    $content =~ s/^$header(.*)$footer$/$1/smx;
    return $content;
}

sub html {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebDriver:GetPageSource'),
            { sessionId => $self->_session_id() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub page_source {
    my ($self) = @_;
    Carp::carp(
        '**** DEPRECATED METHOD - page_source HAS BEEN REPLACED BY html ****');
    return $self->html();
}

sub back {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:Back') ] );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub forward {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:Forward') ] );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub screen_orientation {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('Marionette:GetScreenOrientation')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub switch_to_parent_frame {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:SwitchToParentFrame')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub window_type {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id, $self->_command('Marionette:GetWindowType')
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub switch_to_shadow_root {
    my ( $self, $element ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:SwitchToShadowRoot'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub switch_to_window {
    my ( $self, $window_handle ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebDriver:SwitchToWindow'),
            {
                value  => "$window_handle",
                name   => "$window_handle",
                handle => "$window_handle",
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub switch_to_frame {
    my ( $self, $element ) = @_;
    my $message_id = $self->_new_message_id();
    my $parameters;
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        $parameters = { element => $element->uuid() };
    }
    else {
        $parameters = { ELEMENT => $element->uuid() };
    }
    $self->_send_request(
        [
            _COMMAND(),                                 $message_id,
            $self->_command('WebDriver:SwitchToFrame'), $parameters,
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub go {
    my ( $self, $uri ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebDriver:Navigate'),
            {
                url       => "$uri",
                value     => "$uri",
                sessionId => $self->_session_id()
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub sleep_time_in_ms {
    my ( $self, $new ) = @_;
    my $old = $self->{sleep_time_in_ms} || 1;
    if ( defined $new ) {
        $self->{sleep_time_in_ms} = $new;
    }
    return $old;
}

sub bye {
    my ( $self, $code ) = @_;
    my $found = 1;
    while ( !$found ) {
        eval { &{$code} } and do {
            Time::HiRes::sleep(
                $self->sleep_time_in_ms() / _MILLISECONDS_IN_ONE_SECOND() );
          }
          or do {
            if (
                ( ref $EVAL_ERROR )
                && (
                    (
                        ref $EVAL_ERROR eq
                        'Firefox::Marionette::Exception::NotFound'
                    )
                    || (
                        ref $EVAL_ERROR eq
                        'Firefox::Marionette::Exception::StaleElement' )
                )
              )
            {
                $found = 0;
            }
            else {
                Firefox::Marionette::Exception->throw($EVAL_ERROR);
            }
          };
    }
    return $self;
}

sub await {
    my ( $self, $code ) = @_;
    my $result;
    while ( !$result ) {
        $result = eval { &{$code} } or do {
            if (
                ( ref $EVAL_ERROR )
                && (
                    (
                        ref $EVAL_ERROR eq
                        'Firefox::Marionette::Exception::NotFound'
                    )
                    || (
                        ref $EVAL_ERROR eq
                        'Firefox::Marionette::Exception::StaleElement' )
                    || (
                        ref $EVAL_ERROR eq
                        'Firefox::Marionette::Exception::NoSuchAlert' )
                )
              )
            {
            }
            elsif ( ref $EVAL_ERROR ) {
                Firefox::Marionette::Exception->throw($EVAL_ERROR);
            }
        };
        if ( !$result ) {
            Time::HiRes::sleep(
                $self->sleep_time_in_ms() / _MILLISECONDS_IN_ONE_SECOND() );
        }
    }
    return $result;
}

sub developer {
    my ($self) = @_;
    $self->_initialise_version();
    if (   ( defined $self->{_initial_version} )
        && ( $self->{_initial_version}->{minor} )
        && ( $self->{_initial_version}->{minor} =~ /b\d+$/smx ) )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub nightly {
    my ($self) = @_;
    $self->_initialise_version();
    if (   ( defined $self->{_initial_version} )
        && ( $self->{_initial_version}->{minor} )
        && ( $self->{_initial_version}->{minor} =~ /a\d+$/smx ) )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _get_xpi_path {
    my ( $self, $path ) = @_;
    if ( File::Spec->file_name_is_absolute($path) ) {
    }
    else {
        $path = File::Spec->rel2abs($path);
    }
    my $xpi_path;
    if ( $path =~ /[.]xpi$/smx ) {
        $xpi_path = $path;
    }
    else {
        my $base_directory;
        my ( $volume, $directories, $name );
        if ( -d $path ) {
            ( $volume, $directories, $name ) =
              File::Spec->splitpath( $path, 1 );
            $base_directory = $path;
        }
        else {
            ( $volume, $directories, $name ) = File::Spec->splitpath($path);
            $base_directory = File::Spec->catdir( $volume, $directories );
            if ( $OSNAME eq 'cygwin' ) {
                $base_directory =~
                  s/^\/\//\//smx;   # seems to be a bug in File::Spec for cygwin
            }
        }
        my @directories = File::Spec->splitdir($directories);
        if ( $directories[-1] eq q[] ) {
            pop @directories;
        }
        my $xpi_name = $directories[-1];
        my $zip      = Archive::Zip->new();
        File::Find::find(
            {
                no_chdir => 1,
                wanted   => sub {
                    my $full_path = $File::Find::name;
                    my ( undef, undef, $file_name ) =
                      File::Spec->splitpath($path);
                    if ( $file_name !~ /^[.]/smx ) {
                        my $relative_path =
                          File::Spec->abs2rel( $full_path, $base_directory );
                        my $member;
                        if ( -d $full_path ) {
                            $member = $zip->addDirectory($relative_path);
                        }
                        else {
                            $member =
                              $zip->addFile( $full_path, $relative_path );
                            $member->desiredCompressionMethod(
                                Archive::Zip::COMPRESSION_DEFLATED() );
                        }
                    }

                }
            },
            $base_directory
        );
        $self->_build_local_extension_directory();
        $self->{extension_index} += 1;
        $xpi_path = File::Spec->catfile( $self->{_local_extension_directory},
            $self->{extension_index} . q[_] . $xpi_name . '.xpi' );
        $zip->writeToFileNamed($xpi_path) == Archive::Zip::AZ_OK()
          or Firefox::Marionette::Exception->throw(
            "Failed to write to $xpi_path:$EXTENDED_OS_ERROR");
    }
    return $xpi_path;
}

sub install {
    my ( $self, $path, $temporary ) = @_;
    my $xpi_path = $self->_get_xpi_path($path);
    my $actual_path;
    if ( $self->_ssh() ) {
        if ( !$self->{_addons_directory} ) {
            $self->{_addons_directory} =
              $self->_make_remote_directory(
                $self->_remote_catfile( $self->_root_directory(), 'addons' ) );
        }
        my ( $volume, $directories, $name ) =
          File::Spec->splitpath("$xpi_path");
        my $handle = FileHandle->new( $xpi_path, Fcntl::O_RDONLY() )
          or Firefox::Marionette::Exception->throw(
            "Failed to open $xpi_path for reading:$EXTENDED_OS_ERROR");
        binmode $handle;
        $actual_path =
          $self->_remote_catfile( $self->{_addons_directory}, $name );
        $self->_put_file_via_scp( $handle, $actual_path, 'addon ' . $name );
    }
    elsif ( $OSNAME eq 'cygwin' ) {
        $actual_path = $self->execute( 'cygpath', '-s', '-w', $xpi_path );
    }
    else {
        $actual_path = "$xpi_path";
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('Addon:Install'),
            {
                path      => $actual_path,
                temporary => $temporary ? \1 : \0
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    $self->_clean_local_extension_directory();
    return $self->_response_result_value($response);
}

sub uninstall {
    my ( $self, $id ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('Addon:Uninstall'), { id => $id }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub marionette_protocol {
    my ($self) = @_;
    return $self->{marionette_protocol} || 0;
}

sub application_type {
    my ($self) = @_;
    return $self->{application_type};
}

sub _session_id {
    my ($self) = @_;
    return $self->{session_id};
}

sub _new_message_id {
    my ($self) = @_;
    $self->{last_message_id} += 1;
    return $self->{last_message_id};
}

sub addons {
    my ($self) = @_;
    return $self->{addons};
}

sub _convert_request_to_old_protocols {
    my ( $self, $original ) = @_;
    my $new;
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        $new = $original;
    }
    else {
        $new->{ $self->{_old_protocols_key} } =
          $original->[ _OLD_PROTOCOL_NAME_INDEX() ];
        $new->{parameters} = $original->[ _OLD_PROTOCOL_PARAMETERS_INDEX() ];
        if (   ( ref $new->{parameters} )
            && ( ( ref $new->{parameters} ) eq 'HASH' ) )
        {
            if ( defined $new->{parameters}->{id} ) {
                $new->{parameters}->{element} = $new->{parameters}->{id};
            }
            foreach my $key (
                sort { $a cmp $b }
                keys %{ $original->[ _OLD_PROTOCOL_PARAMETERS_INDEX() ] }
              )
            {
                next if ( $key eq $self->{_old_protocols_key} );
                $new->{$key} = $new->{parameters}->{$key};
            }
        }
    }
    return $new;
}

sub _send_request {
    my ( $self, $object ) = @_;
    $object = $self->_convert_request_to_old_protocols($object);
    my $json   = JSON::encode_json($object);
    my $length = length $json;
    if ( $self->_debug() ) {
        warn ">> $length:$json\n";
    }
    my $result;
    if ( $self->alive() ) {
        $result = syswrite $self->_socket(), "$length:$json";
    }
    if ( !defined $result ) {
        my $socket_error = $EXTENDED_OS_ERROR;
        if ( $self->alive() ) {
            Firefox::Marionette::Exception->throw(
                "Failed to send request to firefox:$socket_error");
        }
        else {
            my $error_message =
              $self->error_message() ? $self->error_message() : q[];
            Firefox::Marionette::Exception->throw($error_message);
        }
    }
    return;
}

sub _read_from_socket {
    my ($self) = @_;
    my $number_of_bytes_in_response;
    my $initial_buffer;
    while ( ( !defined $number_of_bytes_in_response ) && ( $self->alive() ) ) {
        my $number_of_bytes = sysread $self->_socket(), my $octet, 1;
        if ( defined $number_of_bytes ) {
            $initial_buffer .= $octet;
        }
        else {
            my $socket_error = $EXTENDED_OS_ERROR;
            if ( $self->alive() ) {
                Firefox::Marionette::Exception->throw(
"Failed to read size of response from socket to firefox:$socket_error"
                );
            }
            else {
                my $error_message =
                  $self->error_message() ? $self->error_message() : q[];
                Firefox::Marionette::Exception->throw($error_message);
            }
        }
        if ( $initial_buffer =~ s/^(\d+)://smx ) {
            ($number_of_bytes_in_response) = ($1);
        }
    }
    if ( !defined $self->{_initial_packet_size} ) {
        $self->{_initial_packet_size} = $number_of_bytes_in_response;
    }
    my $number_of_bytes_already_read = 0;
    my $json                         = q[];
    while (( defined $number_of_bytes_in_response )
        && ( $number_of_bytes_already_read < $number_of_bytes_in_response )
        && ( $self->alive() ) )
    {
        my $number_of_bytes_read = sysread $self->_socket(), my $buffer,
          $number_of_bytes_in_response - $number_of_bytes_already_read;
        if ( defined $number_of_bytes_read ) {
            $json .= $buffer;
            $number_of_bytes_already_read += $number_of_bytes_read;
        }
        else {
            my $socket_error = $EXTENDED_OS_ERROR;
            if ( $self->alive() ) {
                Firefox::Marionette::Exception->throw(
"Failed to read response from socket to firefox:$socket_error"
                );
            }
            else {
                my $error_message =
                  $self->error_message() ? $self->error_message() : q[];
                Firefox::Marionette::Exception->throw($error_message);
            }
        }
    }
    if ( ( $self->_debug() ) && ( defined $number_of_bytes_in_response ) ) {
        warn "<< $number_of_bytes_in_response:$json\n";
    }
    return $self->_decode_json($json);
}

sub _decode_json {
    my ( $self, $json ) = @_;
    my $parameters;
    eval { $parameters = JSON::decode_json($json); } or do {
        if ( $self->alive() ) {
            if ($EVAL_ERROR) {
                chomp $EVAL_ERROR;
                die "$EVAL_ERROR\n";
            }
        }
        else {
            my $error_message =
              $self->error_message() ? $self->error_message() : q[];
            Firefox::Marionette::Exception->throw($error_message);
        }
    };
    return $parameters;
}

sub _socket {
    my ($self) = @_;
    return $self->{_socket};
}

sub _get_response {
    my ( $self, $message_id, $parameters ) = @_;
    my $next_message = $self->_read_from_socket();
    my $response =
      Firefox::Marionette::Response->new( $next_message, $parameters );
    if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() ) {
        while ( $response->message_id() < $message_id ) {
            $next_message = $self->_read_from_socket();
            $response =
              Firefox::Marionette::Response->new( $next_message, $parameters );
        }
    }
    return $response;
}

sub _signal_number {
    my ( $proto, $name ) = @_;
    my @sig_nums  = split q[ ], $Config{sig_num};
    my @sig_names = split q[ ], $Config{sig_name};
    my %signals_by_name;
    my $idx = 0;
    foreach my $sig_name (@sig_names) {
        $signals_by_name{$sig_name} = $sig_nums[$idx];
        $idx += 1;
    }
    return $signals_by_name{$name};
}

sub DESTROY {
    my ($self) = @_;
    local $CHILD_ERROR = 0;
    if (   ( defined $self->{creation_pid} )
        && ( $self->{creation_pid} == $PROCESS_ID ) )
    {
        if ( $self->{survive} ) {
            if ( $self->_session_id() ) {
                $self->delete_session();
            }
        }
        else {
            $self->quit();
            if ( $self->_ssh() ) {
                $self->_cleanup_remote_filesystem();
                $self->_terminate_master_control_via_ssh();
            }
            $self->_cleanup_local_filesystem();
        }
    }
    return;
}

sub _cleanup_local_filesystem {
    my ($self) = @_;
    if ( $self->_reconnected() ) {
        if ( $self->{_ssh_local_directory} ) {
            File::Path::rmtree( $self->{_ssh_local_directory}, 0, 0 );
        }
        delete $self->{_ssh_local_directory};
        if ( $self->_ssh() ) {
        }
        else {
            if ( $self->{_root_directory} ) {
                File::Path::rmtree( $self->{_root_directory}, 0, 0 );
            }
            delete $self->{_root_directory};
        }
    }
    return;
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette - Automate the Firefox browser with the Marionette protocol

=head1 VERSION

Version 1.00_03

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    say $firefox->find_tag('title')->property('innerHTML'); # same as $firefox->title();

    say $firefox->html();

    $firefox->find_class('container-fluid')->find_id('search-input')->type('Test::More');

    my $file_handle = $firefox->selfie();

    $firefox->find('//button[@name="lucky"]')->click();

    $firefox->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

=head1 DESCRIPTION

This is a client module to automate the Mozilla Firefox browser via the L<Marionette protocol|https://developer.mozilla.org/en-US/docs/Mozilla/QA/Marionette/Protocol>

=head1 SUBROUTINES/METHODS

=head2 accept_alert

accepts a currently displayed modal message box

=head2 accept_connections

Enables or disables accepting new socket connections.  By calling this method with false the server will not accept any further connections, but existing connections will not be forcible closed. Use true to re-enable accepting connections.

Please note that when closing the connection via the client you can end-up in a non-recoverable state if it hasn't been enabled before.

=head2 active_element

returns the active element of the current browsing context's document element, if the document element is non-null.

=head2 add_cookie

accepts a single L<cookie|Firefox::Marionette::Cookie> object as the first parameter and adds it to the current cookie jar.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 add_header

accepts a hash of HTTP headers to include in every future HTTP Request.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();
    my $uuid = UUID::uuid();
    $firefox->add_header( 'Track-my-automated-tests' => $uuid );
    $firefox->go('https://metacpan.org/');

these headers are added to any existing headers.  To clear headers, see the L<delete_header|Firefox::Marionette#delete_headers> method

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->delete_header( 'Accept' )->add_header( 'Accept' => 'text/perl' )->go('https://metacpan.org/');

will only send out an L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> header that looks like C<Accept: text/perl>.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->add_header( 'Accept' => 'text/perl' )->go('https://metacpan.org/');

by itself, will send out an L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> header that may resemble C<Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8, text/perl>. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 add_site_header

accepts a host name and a hash of HTTP headers to include in every future HTTP Request that is being sent to that particular host.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();
    my $uuid = UUID::uuid();
    $firefox->add_site_header( 'metacpan.org', 'Track-my-automated-tests' => $uuid );
    $firefox->go('https://metacpan.org/');

these headers are added to any existing headers going to the metacpan.org site, but no other site.  To clear site headers, see the L<delete_site_header|Firefox::Marionette#delete_site_headers> method

=head2 addons

returns if pre-existing addons (extensions/themes) are allowed to run.  This will be true for Firefox versions less than 55, as -safe-mode cannot be automated.

=head2 alert_text

Returns the message shown in a currently displayed modal message box

=head2 alive

This method returns true or false depending on if the Firefox process is still running.

=head2 application_type

returns the application type for the Marionette protocol.  Should be 'gecko'.

=head2 async_script 

accepts a scalar containing a javascript function that is executed in the browser.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

The executing javascript is subject to the L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.

=head2 attribute 

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a scalar attribute name as the second parameter.  It returns the initial value of the attribute with the supplied name.  This method will return the initial content, the L<property|Firefox::Marionette#property> method will return the current content.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_id('search_input');
    !defined $element->attribute('value') or die "attribute is not defined!");
    $element->type('Test::More');
    !defined $element->attribute('value') or die "attribute is still not defined!");

=head2 await

accepts a subroutine reference as a parameter and then executes the subroutine.  If a L<not found|Firefox::Marionette::Exception::NotFound> exception is thrown, this method will sleep for L<sleep_time_in_ms|Firefox::Marionette#sleep_time_in_ms> milliseconds and then execute the subroutine again.  When the subroutine executes successfully, it will return what the subroutine returns.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(sleep_time_in_ms => 5)->go('https://metacpan.org/');

    $firefox->find_id('search-input')->type('Test::More');

    $firefox->find_name('lucky')->click();

    $firefox->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

=head2 back

causes the browser to traverse one step backward in the joint history of the current browsing context.  The browser will wait for the one step backward to complete or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 browser_version

This method returns version of firefox.

=head2 bye

accepts a subroutine reference as a parameter and then executes the subroutine.  If the subroutine executes successfully, this method will sleep for L<sleep_time_in_ms|Firefox::Marionette#sleep_time_in_ms> milliseconds and then execute the subroutine again.  When a L<not found|Firefox::Marionette::Exception::NotFound> exception is thrown, this method will return L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_id('search-input')->type('Test::More');

    $firefox->find_name('lucky')->click();

    $firefox->bye(sub { $firefox->find_name('lucky') })->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

=head2 capabilities

returns the L<capabilities|Firefox::Marionette::Capabilities> of the current firefox binary.  You can retrieve L<timeouts|Firefox::Marionette::Timeouts> or a L<proxy|Firefox::Marionette::Proxy> with this method.

=head2 child_error

This method returns the $? (CHILD_ERROR) for the Firefox process, or undefined if the process has not yet exited.

=head2 chrome_window_handle

returns an server-assigned integer identifiers for the current chrome window that uniquely identifies it within this Marionette instance.  This can be used to switch to this window at a later point. This corresponds to a window that may itself contain tabs.

=head2 chrome_window_handles

returns identifiers for each open chrome window for tests interested in managing a set of chrome windows and tabs separately.

=head2 clear

accepts a L<element|Firefox::Marionette::Element> as the first parameter and clears any user supplied input

=head2 click

accepts a L<element|Firefox::Marionette::Element> as the first parameter and sends a 'click' to it.  The browser will wait for any page load to complete or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  The L<click|Firefox::Marionette#click> method is also used to choose an option in a select dropdown.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(visible => 1)->go('https://ebay.com');
    my $select = $firefox->find_tag('select');
    foreach my $option ($select->find_tag('option')) {
        if ($option->property('value') == 58058) { # Computers/Tablets & Networking
            $option->click();
        }
    }

=head2 close_current_chrome_window_handle

closes the current chrome window (that is the entire window, not just the tabs).  It returns a list of still available chrome window handles. You will need to L<switch_to_window|Firefox::Marionette#switch_to_window> to use another window.

=head2 close_current_window_handle

closes the current window/tab.  It returns a list of still available window/tab handles.

=head2 context

accepts a string as the first parameter, which may be either 'content' or 'chrome'.  It returns the context type that is Marionette's current target for browsing context scoped commands.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    my $old_context = $firefox->context('chrome');
    $firefox->script(...); # running script in chrome context
    $firefox->context($old_context);

=head2 cookies

returns the L<contents|Firefox::Marionette::Cookie> of the cookie jar in scalar or list context.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://github.com');
    foreach my $cookie ($firefox->cookies()) {
        if (defined $cookie->same_site()) {
            say "Cookie " . $cookie->name() . " has a SameSite of " . $cookie->same_site();
        } else {
            warn "Cookie " . $cookie->name() . " does not have the SameSite attribute defined";
        }
    }

=head2 css

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a scalar CSS property name as the second parameter.  It returns the value of the computed style for that property.

=head2 current_chrome_window_handle 

see L<chrome_window_handle|Firefox::Marionette#chrome_window_handle>.

=head2 delete_cookie

deletes a single cookie by name.  Accepts a scalar containing the cookie name as a parameter.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://github.com');
    foreach my $cookie ($firefox->cookies()) {
        warn "Cookie " . $cookie->name() . " is being deleted";
        $firefox->delete_cookie($cookie->name());
    }
    foreach my $cookie ($firefox->cookies()) {
        die "Should be no cookies here now";
    }

=head2 delete_cookies

here be cookie monsters! This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 delete_header

accepts a list of HTTP header names to delete from future HTTP Requests.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_header( 'User-Agent', 'Accept', 'Accept-Encoding' );

will remove the L<User-Agent|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent>, L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> and L<Accept-Encoding|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding> headers from all future requests

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 delete_session

deletes the current WebDriver session.

=head2 delete_site_header

accepts a host name and a list of HTTP headers names to delete from future HTTP Requests.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_header( 'metacpan.org', 'User-Agent', 'Accept', 'Accept-Encoding' );

will remove the L<User-Agent|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent>, L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> and L<Accept-Encoding|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding> headers from all future requests to metacpan.org.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 developer

returns true if the current version of firefox is a L<developer edition|https://www.mozilla.org/en-US/firefox/developer/> (does the minor version number end with an 'b\d+'?) version.

=head2 dismiss_alert

dismisses a currently displayed modal message box

=head2 download

accepts a filesystem path and returns a matching filehandle.  This is trivial for locally running firefox, but sufficiently complex to justify the method for a remote firefox running over ssh.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new( host => '10.1.2.3' )->go('https://metacpan.org/');

    $firefox->find_class('container-fluid')->find_id('search-input')->type('Test::More');

    $firefox->find('//button[@name="lucky"]')->click();

    $firefox->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

    while(!$firefox->downloads()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {

        my $handle = $firefox->download($path);

        # do something with downloaded file handle

    }

=head2 downloading

returns true if any files in L<downloads|Firefox::Marionette#downloads> end in C<.part>

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_class('container-fluid')->find_id('search-input')->type('Test::More');

    $firefox->find('//button[@name="lucky"]')->click();

    $firefox->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

    while(!$firefox->downloads()) { sleep 1 }

    while($firefox->downloading()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {
        say $path;
    }

=head2 downloads

returns a list of file paths (including partial downloads) of downloads during this Firefox session.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_class('container-fluid')->find_id('search-input')->type('Test::More');

    $firefox->find('//button[@name="lucky"]')->click();

    $firefox->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

    while(!$firefox->downloads()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {
        say $path;
    }

=head2 error_message

This method returns a human readable error message describing how the Firefox process exited (assuming it started okay).  On Win32 platforms this information is restricted to exit code.

=head2 execute

This utility method executes a command with arguments and returns STDOUT as a chomped string.  It is a simple method only intended for the Firefox::Marionette::* modules.

=head2 find

accepts an L<xpath expression|https://en.wikipedia.org/wiki/XPath> as the first parameter and returns the first L<element|Firefox::Marionette::Element> that matches this expression.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find('//input[@id="search-input"]')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find('//input[@id="search-input"]')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_id

accepts an L<id|https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/id> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with a matching 'id' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_id('search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_id('search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_name

This method returns the first L<element|Firefox::Marionette::Element> with a matching 'name' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_name('q')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_name('q')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_class

accepts a L<class name|https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with a matching 'class' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_class('form-control home-search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_class('form-control home-search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_selector

accepts a L<CSS Selector|https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Selectors> as the first parameter and returns the first L<element|Firefox::Marionette::Element> that matches that selector.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_selector('input.home-search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_selector('input.home-search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_tag

accepts a L<tag name|https://developer.mozilla.org/en-US/docs/Web/API/Element/tagName> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with this tag name.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_tag('input');

    # OR in list context 

    foreach my $element ($firefox->find_tag('input')) {
        # do something
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_link

accepts a text string as the first parameter and returns the first link L<element|Firefox::Marionette::Element> that has a matching link text.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_link('API')->click();

    # OR in list context 

    foreach my $element ($firefox->find_link('API')) {
        $element->click();
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 find_partial

accepts a text string as the first parameter and returns the first link L<element|Firefox::Marionette::Element> that has a partially matching link text.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_partial('AP')->click();

    # OR in list context 

    foreach my $element ($firefox->find_partial('AP')) {
        $element->click();
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. 

=head2 forward

causes the browser to traverse one step forward in the joint history of the current browsing context. The browser will wait for the one step forward to complete or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 full_screen

full screens the firefox window. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 go

Navigates the current browsing context to the given L<URI|URI> and waits for the document to load or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->go('https://metacpan.org/'); # will only return when metacpan.org is FULLY loaded (including all images / js / css)

To make the L<go|Firefox::Marionette#go> method return quicker, you need to set the L<page load strategy|Firefox::Marionette::Capabilities#page_load_strategy> L<capability|Firefox::Marionette::Capabilities> to an appropriate value, such as below;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( page_load_strategy => 'eager' ));
    $firefox->go('https://metacpan.org/'); # will return once the main document has been loaded and parsed, but BEFORE sub-resources (images/stylesheets/frames) have been loaded.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 har

returns a hashref representing the L<http archive|https://en.wikipedia.org/wiki/HAR_(file_format)> of the session.  This function is subject to the L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.  It is also possible for the function to hang (until the L<script|Firefox::Marionette::Timeouts#script> timeout) if the original L<devtools|https://developer.mozilla.org/en-US/docs/Tools> window is closed.  The hashref has been designed to be accepted by the L<Archive::Har|Archive::Har> module.  This function should be considered experimental.  Feedback welcome.

    use Firefox::Marionette();
    use Archive::Har();
    use v5.10;

    my $firefox = Firefox::Marionette->new(visible => 1, debug => 1, har => 1);

    $firefox->go("http://metacpan.org/");

    $firefox->find('//input[@id="search-input"]')->type('Test::More');
    $firefox->find_name('lucky')->click();

    my $har = Archive::Har->new();
    $har->hashref($firefox->har());

    foreach my $entry ($har->entries()) {
        say $entry->request()->url() . " spent " . $entry->timings()->connect() . " ms establishing a TCP connection";
    }

=head2 html

returns the page source of the content document.  This page source can be wrapped in html that firefox provides.  See the L<json|Firefox::Marionette#json> method for an alternative when dealing with response content types such as application/json and L<strip|Firefox::Marionette#strip> for an alterative when dealing with other non-html content types such as text/plain.

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->go('https://metacpan.org/')->html();

=head2 install

accepts the following as the first parameter;

=over 4

=item * path to an L<xpi file|https://developer.mozilla.org/en-US/docs/Mozilla/XPI>.

=item * path to a directory containing L<firefox extension source code|https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension>.  This directory will be packaged up as an unsigned xpi file.

=item * path to a top level file (such as L<manifest.json|https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Anatomy_of_a_WebExtension#manifest.json>) in a directory containing L<firefox extension source code|https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension>.  This directory will be packaged up as an unsigned xpi file.

=back

and an optional true/false second parameter to indicate if the xpi file should be a L<temporary extension|https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/> (just for the existance of this browser instance).  Unsigned xpi files L<may only be loaded temporarily|https://wiki.mozilla.org/Add-ons/Extension_Signing> (except for L<nightly firefox installations|https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly>).  It returns the GUID for the addon which may be used as a parameter to the L<uninstall|Firefox::Marionette#uninstall> method.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $extension_id = $firefox->install('/full/path/to/gnu_terry_pratchett-0.4-an+fx.xpi');

    # OR downloading and installing source code

    system { 'git' } 'git', 'clone', 'https://github.com/kkapsner/CanvasBlocker.git';

    if ($firefox->nightly()) {

        $extension_id = $firefox->install('./CanvasBlocker'); # permanent install for unsigned packages in nightly firefox

    } else {

        $extension_id = $firefox->install('./CanvasBlocker', 1); # temp install for normal firefox

    }

=head2 interactive

returns true if C<document.readyState === "interactive"> or if L<loaded|Firefox::Marionette#loaded> is true

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_id('search_input')->type('Type::More');
    $firefox->find('//button[@name="lucky"]')->click();
    while(!$firefox->interactive()) {
        # redirecting to Test::More page
    }

=head2 is_displayed

accepts an L<element|Firefox::Marionette::Element> as the first parameter.  This method returns true or false depending on if the element is displayed.

=head2 is_enabled

accepts an L<element|Firefox::Marionette::Element> as the first parameter.  This method returns true or false depending on if the element is enabled.

=head2 is_selected

accepts an L<element|Firefox::Marionette::Element> as the first parameter.  This method returns true or false depending on if the element is selected.

=head2 json

returns a L<JSON|JSON> object that has been parsed from the page source of the content document.  This is a convenience method that wraps the L<strip|Firefox::Marionette#strip> method.

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->go('https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette")->json()->{version};

=head2 loaded

returns true if C<document.readyState === "complete">

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_id('search_input')->type('Type::More');
    $firefox->find('//button[@name="lucky"]')->click();
    while(!$firefox->loaded()) {
        # redirecting to Test::More page
    }

=head2 marionette_protocol

returns the version for the Marionette protocol.  Current most recent version is '3'.

=head2 maximise

maximises the firefox window. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 mime_types

returns a list of MIME types that will be downloaded by firefox and made available from the L<downloads|Firefox::Marionette#downloads> method

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new(mime_types => [ 'application/pkcs10' ])

    foreach my $mime_type ($firefox->mime_types()) {
        say $mime_type;
    }

=head2 minimise

minimises the firefox window. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 new
 
accepts an optional hash as a parameter.  Allowed keys are below;

=over 4

=item * addons - should any firefox extensions and themes be available in this session.  This defaults to "0".

=item * capabilities - use the supplied L<capabilities|Firefox::Marionette::Capabilities> object, for example to set whether the browser should L<accept insecure certs|Firefox::Marionette::Capabilities#accept_insecure_certs> or whether the browser should use a L<proxy|Firefox::Marionette::Proxy>.

=item * chatty - Firefox is extremely chatty on the network, including checking for the lastest malware/phishing sites, updates to firefox/etc.  This option is therefore off ("0") by default, however, it can be switched on ("1") if required.  Even with chatty switched off, connections to firefox.settings.services.mozilla.com may still be made.  The only way to prevent this seems to be to set firefox.settings.services.mozilla.com to 127.0.0.1 via L</etc/hosts|https://en.wikipedia.org/wiki//etc/hosts>.  NOTE: that this option only works when profile_name/profile is not specified.

=item * debug - should firefox's debug to be available via STDERR. This defaults to "0". Any ssh connections will also be printed to STDERR.

=item * developer - only allow a L<developer edition|https://www.mozilla.org/en-US/firefox/developer/> to be launched.

=item * firefox - use the specified path to the L<Firefox|https://firefox.org/> binary, rather than the default path.

=item * height - set the L<height|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29> of the initial firefox window

=item * har - begin the session with the L<devtools|https://developer.mozilla.org/en-US/docs/Tools> window opened in a separate window.  The L<HAR Export Trigger|https://addons.mozilla.org/en-US/firefox/addon/har-export-trigger/> addon will be loaded into the new session automatically, which means that -safe-mode will not be activated for this session AND this functionality will only be available for Firefox 61+.

=item * host - use L<ssh|https://man.openbsd.org/ssh.1> to create and automate firefox on the specified host.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|Firefox::Marionette#REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH>.

=item * implicit - a shortcut to allow directly providing the L<implicit|Firefox::Marionette::Timeout#implicit> timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.

=item * mime_types - any MIME types that Firefox will encounter during this session.  MIME types that are not specified will result in a hung browser (the File Download popup will appear).

=item * nightly - only allow a L<nightly release|https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly> to be launched.

=item * port - if the "host" parameter is also set, use L<ssh|https://man.openbsd.org/ssh.1> to create and automate firefox via the specified port.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|Firefox::Marionette#REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH>.

=item * page_load - a shortcut to allow directly providing the L<page_load|Firefox::Marionette::Timeouts#page_load> timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.

=item * profile - create a new profile based on the supplied L<profile|Firefox::Marionette::Profile>.  NOTE: firefox ignores any changes made to the profile on the disk while it is running.

=item * profile_name - pick a specific existing profile to automate, rather than creating a new profile.  L<Firefox|https://firefox.com> refuses to allow more than one instance of a profile to run at the same time.  Profile names can be obtained by using the L<Firefox::Marionette::Profile::names()|Firefox::Marionette::Profile#names> method.  NOTE: firefox ignores any changes made to the profile on the disk while it is running.

=item * reconnect - an experimental parameter to allow a reconnection to firefox that a connection has been discontinued.  See the survive parameter.

=item * script - a shortcut to allow directly providing the L<script|Firefox::Marionette::Timeout#script> timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.

=item * seer - this option is switched off "0" by default.  When it is switched on "1", it will activate the various speculative and pre-fetch options for firefox.  NOTE: that this option only works when profile_name/profile is not specified.

=item * sleep_time_in_ms - the amount of time (in milliseconds) that this module should sleep when unsuccessfully calling the subroutine provided to the L<await|Firefox::Marionette#await> or L<bye|Firefox::Marionette#bye> methods.  This defaults to "1" millisecond.

=item * survive - if this is set to a true value, firefox will not automatically exit when the object goes out of scope.  See the reconnect parameter for an experimental technique for reconnecting.

=item * trust - give a path to a L<root certificate|https://en.wikipedia.org/wiki/Root_certificate> that will be trusted for this session.  The certificate will be imported by the L<NSS certutil|https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS/tools/NSS_Tools_certutil> binary.  If this binary does not exist in the L<PATH|https://en.wikipedia.org/wiki/PATH_(variable)>, an exception will be thrown.  For Linux/BSD systems, L<NSS certutil|https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS/tools/NSS_Tools_certutil> should be available via your package manager.  For OS X and Windows based platforms, it will be more difficult.

=item * timeouts - a shortcut to allow directly providing a L<timeout|Firefox::Marionette::Timeout> object, instead of needing to use timeouts from the capabilities parameter.  Overrides the timeouts provided (if any) in the capabilities parameter.

=item * port - if the "host" parameter is also set, use L<ssh|https://man.openbsd.org/ssh.1> to create and automate firefox with the specified user.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|Firefox::Marionette#REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH>.

=item * visible - should firefox be visible on the desktop.  This defaults to "0".

=item * waterfox - only allow a binary that looks like a L<waterfox version|https://www.waterfox.net/> to be launched.

=item * width - set the L<width|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29> of the initial firefox window

=back

This method returns a new C<Firefox::Marionette> object, connected to an instance of L<firefox|https://firefox.com>.  In a non MacOS/Win32/Cygwin environment, if necessary (no DISPLAY variable can be found and the visible parameter to the new method has been set to true) and possible (Xvfb can be executed successfully), this method will also automatically start an L<Xvfb|https://en.wikipedia.org/wiki/Xvfb> instance.
 
    use Firefox::Marionette();

    my $remote_darwin_firefox = Firefox::Marionette->new(
                     debug => 1,
                     host => '10.1.2.3',
                     trust => '/path/to/root_ca.pem',
                     firefox => '/Applications/Firefox.app/Contents/MacOS/firefox'
                                                        ); # start a temporary profile for a remote firefox and load a new CA into the temp profile
    ...

    foreach my $profile_name (Firefox::Marionette::Profile->names()) {
        my $firefox_with_existing_profile = Firefox::Marionette->new( profile_name => $profile_name, visible => 1 );
        ...
    }

=head2 new_window

accepts an optional hash as the parameter.  Allowed keys are below;

=over 4

=item * focus - a boolean field representing if the new window be opened in the foreground (focused) or background (not focused). Defaults to false.

=item * private - a boolean field representing if the new window should be a private window. Defaults to false.

=item * type - the type of the new window. Can be one of 'tab' or 'window'. Defaults to 'tab'.

=back

Returns the window handle for the new window.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $window_handle = $firefox->new_window(type => 'tab');

    $firefox->switch_to_window($window_handle);

=head2 new_session

creates a new WebDriver session.  It is expected that the caller performs the necessary checks on the requested capabilities to be WebDriver conforming.  The WebDriver service offered by Marionette does not match or negotiate capabilities beyond type and bounds checks.

=head2 nightly

returns true if the current version of firefox is a L<nightly release|https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly> (does the minor version number end with an 'a1'?)

=head2 paper_sizes 

returns a list of all the recognised names for paper sizes, such as A4 or LEGAL.

=head2 pdf

returns a L<File::Temp|File::Temp> object containing a PDF encoded version of the current page for printing.

accepts a optional hash as the first parameter with the following allowed keys;

=over 4

=item * landscape - Paper orientation.  Boolean value.  Defaults to false

=item * margin - A hash describing the margins.  The hash may have the following optional keys, 'top', 'left', 'right' and 'bottom'.  All these keys are in cm and default to 1 (~0.4 inches)

=item * page - A hash describing the page.  The hash may have the following keys; 'height' and 'width'.  Both keys are in cm and default to US letter size.  See the 'size' key.

=item * print_background - Print background graphics.  Boolean value.  Defaults to false. 

=item * raw - rather than a file handle containing the PDF, the binary PDF will be returned.

=item * scale - Scale of the webpage rendering.  Defaults to 1.

=item * size - The desired size (width and height) of the pdf, specified by name.  See the page key for an alternative and the L<paper_sizes|Firefox::Marionette#paper_sizes> method for a list of accepted page size names. 

=item * shrink_to_fit - Whether or not to override page size as defined by CSS.  Boolean value.  Defaults to true. 

=back

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $handle = $firefox->pdf();
    foreach my $paper_size ($firefox->paper_sizes()) {
	    $handle = $firefox->pdf(size => $paper_size, landscape => 1, margin => { top => 0.5, left => 1.5 });
            ...
	    print $firefox->pdf(page => { width => 21, height => 27 }, raw => 1);
            ...
    }

=head2 property

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a scalar attribute name as the second parameter.  It returns the current value of the property with the supplied name.  This method will return the current content, the L<attribute|Firefox::Marionette#attribute> method will return the initial content.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_id('search_input');
    $element->property('value') eq '' or die "Initial property is the empty string";
    $element->type('Test::More');
    $element->property('value') eq 'Test::More' or die "This property should have changed!";

    # OR getting the innerHTML property

    my $title = $firefox->find_tag('title')->property('innerHTML'); # same as $firefox->title();

=head2 quit

Marionette will stop accepting new connections before ending the current session, and finally attempting to quit the application.  This method returns the $? (CHILD_ERROR) value for the Firefox process

=head2 rect

accepts a L<element|Firefox::Marionette::Element> as the first parameter and returns the current L<position and size|Firefox::Marionette::Element::Rect> of the L<element|Firefox::Marionette::Element>

=head2 refresh

refreshes the current page.  The browser will wait for the page to completely refresh or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 screen_orientation

returns the current browser orientation.  This will be one of the valid primary orientation values 'portrait-primary', 'landscape-primary', 'portrait-secondary', or 'landscape-secondary'.  This method is only currently available on Android (Fennec).

=head2 script 

accepts a scalar containing a javascript function body that is executed in the browser, and an optional hash as a second parameter.  Allowed keys are below;

=over 4

=item * args - The reference to a list is the arguments passed to the function body.

=item * filename - Filename of the client's program where this script is evaluated.

=item * line - Line in the client's program where this script is evaluated.

=item * new - Forces the script to be evaluated in a fresh sandbox.  Note that if it is undefined, the script will normally be evaluted in a fresh sandbox.

=item * sandbox - Name of the sandbox to evaluate the script in.  The sandbox is cached for later re-use on the same L<window|https://developer.mozilla.org/en-US/docs/Web/API/Window> object if C<new> is false.  If he parameter is undefined, the script is evaluated in a mutable sandbox.  If the parameter is "system", it will be evaluted in a sandbox with elevated system privileges, equivalent to chrome space.

=item * timeout - A timeout to override the default L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.

=back

Returns the result of the javascript function.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if ($firefox->script('return window.find("lucky");')) {
        # luckily!
    }

The executing javascript is subject to the L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.

=head2 selfie

returns a L<File::Temp|File::Temp> object containing a lossless PNG image screenshot.  If an L<element|Firefox::Marionette::Element> is passed as a parameter, the screenshot will be restricted to the element.  

If an L<element|Firefox::Marionette::Element> is not passed as a parameter and the current L<context|Firefox::Marionette#context> is 'chrome', a screenshot of the current viewport will be returned.

If an L<element|Firefox::Marionette::Element> is not passed as a parameter and the current L<context|Firefox::Marionette#context> is 'content', a screenshot of the current frame will be returned.

The parameters after the L<element|Firefox::Marionette::Element> parameter are taken to be a optional hash with the following allowed keys;

=over 4

=item * hash - return a SHA256 hex encoded digest of the PNG image rather than the image itself

=item * full - take a screenshot of the whole document unless the first L<element|Firefox::Marionette::Element> parameter has been supplied.

=item * raw - rather than a file handle containing the screenshot, the binary PNG image will be returned.

=item * scroll - scroll to the L<element|Firefox::Marionette::Element> supplied

=item * highlights - a reference to a list containing L<elements|Firefox::Marionette::Element> to draw a highlight around.  Not available in L<Firefox 70|https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/70#WebDriver_conformance_Marionette> onwards.

=back

=head2 send_alert_text

sends keys to the input field of a currently displayed modal message box

=head2 sleep_time_in_ms

accepts a new time to sleep in L<await|Firefox::Marionette#await> or L<bye|Firefox::Marionette#bye> methods and returns the previous time.  The default time is "1" millisecond.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(sleep_time_in_ms => 5); # setting default time to 5 milliseconds

    my $old_time_in_ms = $firefox->sleep_time_in_ms(8); # setting default time to 8 milliseconds, returning 5 (milliseconds)

=head2 strip

returns the page source of the content document after an attempt has been made to remove typical firefox html wrappers of non html content types such as text/plain and application/json.  See the L<json|Firefox::Marionette#json> method for an alternative when dealing with response content types such as application/json and L<html|Firefox::Marionette#html> for an alterative when dealing with html content types.  This is a convenience method that wraps the L<html|Firefox::Marionette#html> method.

    use Firefox::Marionette();
    use JSON();
    use v5.10;

    say JSON::decode_json(Firefox::Marionette->new()->go('https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette")->strip())->{version};

=head2 switch_to_frame

accepts a L<frame|Firefox::Marionette::Element> as a parameter and switches to it within the current window.

=head2 switch_to_parent_frame

set the current browsing context for future commands to the parent of the current browsing context

=head2 switch_to_window

accepts a window handle (either the result of L<window_handles|Firefox::Marionette#window_handles> or a window name as a parameter and switches focus to this window.

=head2 tag_name

accepts a L<Firefox::Marionette::Element|Firefox::Marionette::Element> object as the first parameter and returns the relevant tag name.  For example 'a' or 'input'.

=head2 text

accepts a L<element|Firefox::Marionette::Element> as the first parameter and returns the text that is contained by that element (if any)

=head2 timeouts

returns the current L<timeouts|Firefox::Marionette::Timeouts> for page loading, searching, and scripts.

=head2 title

returns the current title of the window.

=head2 type

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a string as the second parameter.  It sends the string to the specified L<element|Firefox::Marionette::Element> in the current page, such as filling out a text box. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 uninstall

accepts the GUID for the addon to uninstall.  The GUID is returned when from the L<install|Firefox::Marionette#install> method.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $extension_id = $firefox->install('/full/path/to/gnu_terry_pratchett-0.4-an+fx.xpi');

    # do something

    $firefox->uninstall($extension_id); # not recommended to uninstall this extension IRL.

=head2 uri

returns the current L<URI|URI> of current top level browsing context for Desktop.  It is equivalent to the javascript C<document.location.href>

=head2 window_handle

returns the current window's handle. On desktop this typically corresponds to the currently selected tab.  returns an opaque server-assigned identifier to this window that uniquely identifies it within this Marionette instance.  This can be used to switch to this window at a later point.

=head2 window_handles

returns a list of top-level browsing contexts. On desktop this typically corresponds to the set of open tabs for browser windows, or the window itself for non-browser chrome windows.  Each window handle is assigned by the server and is guaranteed unique, however the return array does not have a specified ordering.

=head2 window_rect

accepts an optional L<position and size|Firefox::Marionette::Window::Rect> as a parameter, sets the current browser window to that position and size and returns the previous L<position, size and state|Firefox::Marionette::Window::Rect> of the browser window.  If no parameter is supplied, it returns the current  L<position, size and state|Firefox::Marionette::Window::Rect> of the browser window.

=head2 window_type

returns the current window's type.  This should be 'navigator:browser'.

=head2 xvfb

returns the pid of the xvfb process if it exists.

=head1 REMOTE AUTOMATION OF FIREFOX VIA SSH

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( host => 'remote.example.org', debug => 1 );
    $firefox->go('https://metacpan.org/');

    # OR specify a different user to login as ...
    
    my $firefox = Firefox::Marionette->new( host => 'remote.example.org', user => 'R2D2', debug => 1 );
    $firefox->go('https://metacpan.org/');

    # OR specify a different port to connect to
    
    my $firefox = Firefox::Marionette->new( host => 'remote.example.org', port => 2222, debug => 1 );
    $firefox->go('https://metacpan.org/');

This module has support for creating and automating an instance of Firefox on a remote node.  It has been tested against a number of operating systems, including recent version of L<Windows 10 or Windows Server 2019|https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse>, OS X, and Linux and BSD distributions.  It expects to be able to login to the remote node via public key authentication.  It can be further secured via the L<command|https://man.openbsd.org/sshd#command=_command_> option in the L<OpenSSH|https://www.openssh.com/> L<authorized_keys|https://man.openbsd.org/sshd#AUTHORIZED_KEYS_FILE_FORMAT> file such as;

    no-agent-forwarding,no-pty,no-X11-forwarding,permitopen="127.0.0.1:*",command="/usr/local/bin/ssh-auth-cmd-marionette" ssh-rsa AAAA ... == user@server

As an example, the L<ssh-auth-cmd-marionette|ssh-auth-cmd-marionette> command is provided as part of this distribution.

When using ssh, Firefox::Marionette will attempt to pass the L<TMPDIR|https://en.wikipedia.org/wiki/TMPDIR> environment variable across the ssh connection to make cleanups easier.  In order to allow this, the L<AcceptEnv|https://man.openbsd.org/sshd_config#AcceptEnv> setting in the remote L<sshd configuration|https://man.openbsd.org/sshd_config> should be set to allow TMPDIR, which will look like;

    AcceptEnv TMPDIR

This module uses L<ControlMaster|https://man.openbsd.org/ssh_config#ControlMaster> functionality when using L<ssh|https://man.openbsd.org/ssh>, for a useful speedup of executing remote commands.  Unfortunately, when using ssh to move from a L<cygwin|https://gcc.gnu.org/wiki/SSH_connection_caching>, L<Windows 10 or Windows Server 2019|https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse> node to a remote environment, we cannot use L<ControlMaster|https://man.openbsd.org/ssh_config#ControlMaster>, because at this time, Windows L<does not support ControlMaster|https://github.com/Microsoft/vscode-remote-release/issues/96> and therefore this type of automation is still possible, but slower than other client platforms.

=head1 DIAGNOSTICS

=over
 
=item C<< Failed to correctly setup the Firefox process >>

The module was unable to retrieve a session id and capabilities from Firefox when it requests a L<new_session|Firefox::Marionette#new_session> as part of the initial setup of the connection to Firefox.

=item C<< Failed to correctly determined the Firefox process id through the initial connection capabilities >>
 
The module was found that firefox is reporting through it's L<Capabilities|Firefox::Marionette::Capabilities#moz_process_id> object a different process id than this module was using.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.
 
=item C<< '%s --version' did not produce output that could be parsed.  Assuming modern Marionette is available:%s >>
 
The Firefox binary did not produce a version number that could be recognised as a Firefox version number.
 
=item C<< Failed to create process from '%s':%s >>
 
The module was to start Firefox process in a Win32 environment.  Something is seriously wrong with your environment.
 
=item C<< Failed to redirect %s to %s:%s >>
 
The module was unable to redirect a file handle's output.  Something is seriously wrong with your environment.
 
=item C<< Failed to exec %s:%s >>
 
The module was unable to run the Firefox binary.  Check the path is correct and the current user has execute permissions.
 
=item C<< Failed to fork:%s >>
 
The module was unable to fork itself, prior to executing a command.  Check the current C<ulimit> for max number of user processes.
 
=item C<< Failed to open directory '%s':%s >>
 
The module was unable to open a directory.  Something is seriously wrong with your environment.
 
=item C<< Failed to close directory '%s':%s >>
 
The module was unable to close a directory.  Something is seriously wrong with your environment.
 
=item C<< Failed to open '%s' for writing:%s >>
 
The module was unable to create a file in your temporary directory.  Maybe your disk is full?
 
=item C<< Failed to open temporary file for writing:%s >>
 
The module was unable to create a file in your temporary directory.  Maybe your disk is full?
 
=item C<< Failed to close '%s':%s >>
 
The module was unable to close a file in your temporary directory.  Maybe your disk is full?
 
=item C<< Failed to close temporary file:%s >>
 
The module was unable to close a file in your temporary directory.  Maybe your disk is full?
 
=item C<< Failed to create temporary directory:%s >>
 
The module was unable to create a directory in your temporary directory.  Maybe your disk is full?
 
=item C<< Failed to clear the close-on-exec flag on a temporary file:%s >>
 
The module was unable to call fcntl using F_SETFD for a file in your temporary directory.  Something is seriously wrong with your environment.
 
=item C<< Failed to seek to start of temporary file:%s >>
 
The module was unable to seek to the start of a file in your temporary directory.  Something is seriously wrong with your environment.
 
=item C<< Failed to create a socket:%s >>
 
The module was unable to even create a socket.  Something is seriously wrong with your environment.
 
=item C<< Failed to connect to %s on port %d:%s >>
 
The module was unable to connect to the Marionette port.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.
 
=item C<< Firefox killed by a %s signal (%d) >>
 
Firefox crashed after being hit with a signal.  
 
=item C<< Firefox exited with a %d >>
 
Firefox has exited with an error code
 
=item C<< Failed to bind socket:%s >>
 
The module was unable to bind a socket to any port.  Something is seriously wrong with your environment.
 
=item C<< Failed to close random socket:%s >>
 
The module was unable to close a socket without any reads or writes being performed on it.  Something is seriously wrong with your environment.
 
=item C<< moz:headless has not been determined correctly >>
 
The module was unable to correctly determine whether Firefox is running in "headless" or not.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.
 
=item C<< %s method requires a Firefox::Marionette::Element parameter >>
 
This function was called incorrectly by your code.  Please supply a L<Firefox::Marionette::Element|Firefox::Marionette::Element> parameter when calling this function.
 
=item C<< Failed to write to temporary file:%s >>
 
The module was unable to write to a file in your temporary directory.  Maybe your disk is full?

=item C<< Failed to close socket to firefox:%s >>
 
The module was unable to even close a socket.  Something is seriously wrong with your environment.
 
=item C<< Failed to send request to firefox:%s >>
 
The module was unable to perform a syswrite on the socket connected to firefox.  Maybe firefox crashed?
 
=item C<< Failed to read size of response from socket to firefox:%s >>
 
The module was unable to read from the socket connected to firefox.  Maybe firefox crashed?
 
=item C<< Failed to read response from socket to firefox:%s >>
 
The module was unable to read from the socket connected to firefox.  Maybe firefox crashed?
 
=back

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette requires no configuration files or environment variables.  It will however use the DISPLAY and XAUTHORITY environment variables to try to connect to an X Server.
It will also use the HTTP_PROXY, HTTPS_PROXY, FTP_PROXY and ALL_PROXY environment variables as defaults if the session L<capabilities|Firefox::Marionette::Capabilities> do not specify proxy information.

=head1 DEPENDENCIES

Firefox::Marionette requires the following non-core Perl modules
 
=over
 
=item *
L<JSON|JSON>
 
=item *
L<URI|URI>
 
=back

=head1 INCOMPATIBILITIES

None reported.  Always interested in any products with marionette support that this module could be patched to work with.


=head1 BUGS AND LIMITATIONS

Currently the following Marionette methods have not been implemented;

=over
 
=item * WebDriver:ReleaseAction

=item * WebDriver:PerformActions

=item * WebDriver:SetScreenOrientation

=back

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-firefox-marionette@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

=over

=item *
L<MozRepl|MozRepl>

=item *
L<Selenium::Firefox|Selenium::Firefox>

=item *
L<Firefox::Application|Firefox::Application>

=item *
L<Mozilla::Mechanize|Mozilla::Mechanize>

=item *
L<Gtk2::MozEmbed|Gtk2::MozEmbed>

=back

=head1 AUTHOR

David Dick  C<< <ddick@cpan.org> >>

=head1 ACKNOWLEDGEMENTS
 
Thanks to the entire Mozilla organisation for a great browser and to the team behind Marionette for providing an interface for automation.
 
Thanks to L<Jan Odvarko|http://www.softwareishard.com/blog/about/> for creating the L<HAR Export Trigger|https://github.com/firefox-devtools/har-export-trigger> extension for Firefox.

Thanks also to the authors of the documentation in the following sources;

=over 4

=item * L<Marionette Protocol|https://firefox-source-docs.mozilla.org/testing/marionette/marionette/index.html>

=item * L<Marionette Documentation|https://firefox-source-docs.mozilla.org/testing/marionette/marionette/index.html>

=item * L<Marionette driver.js|https://hg.mozilla.org/mozilla-central/file/tip/testing/marionette/driver.js>

=item * L<about:config|http://kb.mozillazine.org/About:config_entries>

=item * L<nsIPrefService interface|https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIPrefService>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2020, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic/perlartistic>.

The L<Firefox::Marionette::Extension::HarExportTrigger|Firefox::Marionette::Extension::HarExportTrigger> module includes the L<HAR Export Trigger|https://github.com/firefox-devtools/har-export-trigger>
extension which is licensed under the L<Mozilla Public License 2.0|https://www.mozilla.org/en-US/MPL/2.0/>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
