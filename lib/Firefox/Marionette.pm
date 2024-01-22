package Firefox::Marionette;

use warnings;
use strict;
use Firefox::Marionette::Response();
use Firefox::Marionette::Bookmark();
use Firefox::Marionette::Element();
use Firefox::Marionette::Cache();
use Firefox::Marionette::Cookie();
use Firefox::Marionette::Display();
use Firefox::Marionette::Window::Rect();
use Firefox::Marionette::Element::Rect();
use Firefox::Marionette::GeoLocation();
use Firefox::Marionette::Timeouts();
use Firefox::Marionette::Image();
use Firefox::Marionette::Link();
use Firefox::Marionette::Login();
use Firefox::Marionette::Capabilities();
use Firefox::Marionette::Certificate();
use Firefox::Marionette::Profile();
use Firefox::Marionette::Proxy();
use Firefox::Marionette::Exception();
use Firefox::Marionette::Exception::Response();
use Firefox::Marionette::UpdateStatus();
use Firefox::Marionette::ShadowRoot();
use Firefox::Marionette::WebAuthn::Authenticator();
use Firefox::Marionette::WebAuthn::Credential();
use Firefox::Marionette::WebFrame();
use Firefox::Marionette::WebWindow();
use Waterfox::Marionette::Profile();
use Compress::Zlib();
use Config::INI::Reader();
use Crypt::URandom();
use Archive::Zip();
use Symbol();
use JSON();
use IO::Handle();
use IPC::Open3();
use Socket();
use English qw( -no_match_vars );
use POSIX();
use Scalar::Util();
use File::Find();
use File::Path();
use File::Spec();
use URI();
use URI::Escape();
use Time::HiRes();
use Time::Local();
use File::Temp();
use File::stat();
use File::Spec::Unix();
use File::Spec::Win32();
use FileHandle();
use MIME::Base64();
use DirHandle();
use XML::Parser();
use Text::CSV_XS();
use Carp();
use Config;
use parent qw(Exporter);

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

our $VERSION = '1.51';

sub _ANYPROCESS                     { return -1 }
sub _COMMAND                        { return 0 }
sub _DEFAULT_HOST                   { return 'localhost' }
sub _DEFAULT_PORT                   { return 2828 }
sub _MARIONETTE_PROTOCOL_VERSION_3  { return 3 }
sub _WIN32_ERROR_SHARING_VIOLATION  { return 0x20 }
sub _NUMBER_OF_MCOOKIE_BYTES        { return 16 }
sub _MAX_DISPLAY_LENGTH             { return 10 }
sub _NUMBER_OF_TERM_ATTEMPTS        { return 4 }
sub _MAX_VERSION_FOR_ANCIENT_CMDS   { return 31 }
sub _MAX_VERSION_FOR_NEW_CMDS       { return 61 }
sub _MAX_VERSION_NO_POINTER_ORIGIN  { return 116 }
sub _MIN_VERSION_FOR_AWAIT          { return 50 }
sub _MIN_VERSION_FOR_NEW_SENDKEYS   { return 55 }
sub _MIN_VERSION_FOR_HEADLESS       { return 55 }
sub _MIN_VERSION_FOR_WD_HEADLESS    { return 56 }
sub _MIN_VERSION_FOR_SAFE_MODE      { return 55 }
sub _MIN_VERSION_FOR_AUTO_LISTEN    { return 55 }
sub _MIN_VERSION_FOR_HOSTPORT_PROXY { return 57 }
sub _MIN_VERSION_FOR_XVFB           { return 12 }
sub _MIN_VERSION_FOR_WEBDRIVER_IDS  { return 63 }
sub _MIN_VERSION_FOR_LINUX_SANDBOX  { return 90 }
sub _MILLISECONDS_IN_ONE_SECOND     { return 1_000 }
sub _DEFAULT_PAGE_LOAD_TIMEOUT      { return 300_000 }
sub _DEFAULT_SCRIPT_TIMEOUT         { return 30_000 }
sub _DEFAULT_IMPLICIT_TIMEOUT       { return 0 }
sub _WIN32_CONNECTION_REFUSED       { return 10_061 }
sub _OLD_PROTOCOL_NAME_INDEX        { return 2 }
sub _OLD_PROTOCOL_PARAMETERS_INDEX  { return 3 }
sub _OLD_INITIAL_PACKET_SIZE        { return 66 }
sub _READ_LENGTH_OF_OPEN3_OUTPUT    { return 50 }
sub _DEFAULT_WINDOW_WIDTH           { return 1920 }
sub _DEFAULT_WINDOW_HEIGHT          { return 1080 }
sub _DEFAULT_DEPTH                  { return 24 }
sub _LOCAL_READ_BUFFER_SIZE         { return 8192 }
sub _WIN32_PROCESS_INHERIT_FLAGS    { return 0 }
sub _DEFAULT_CERT_TRUST             { return 'C,,' }
sub _PALEMOON_VERSION_EQUIV         { return 52 }            # very approx guess
sub _MAX_VERSION_FOR_FTP_PROXY      { return 89 }
sub _DEFAULT_UPDATE_TIMEOUT         { return 300 }           # 5 minutes
sub _MIN_VERSION_NO_CHROME_CALLS    { return 94 }
sub _MIN_VERSION_FOR_SCRIPT_SCRIPT  { return 31 }
sub _MIN_VERSION_FOR_SCRIPT_WO_ARGS { return 60 }
sub _MIN_VERSION_FOR_MODERN_GO      { return 31 }
sub _MIN_VERSION_FOR_MODERN_SWITCH  { return 90 }
sub _MIN_VERSION_FOR_WEBAUTHN       { return 118 }
sub _ACTIVE_UPDATE_XML_FILE_NAME    { return 'active-update.xml' }
sub _NUMBER_OF_CHARS_IN_TEMPLATE    { return 11 }
sub _DEFAULT_ADB_PORT               { return 5555 }
sub _SHORT_GUID_BYTES               { return 9 }
sub _DEFAULT_DOWNLOAD_TIMEOUT       { return 300 }
sub _CREDENTIAL_ID_LENGTH           { return 32 }

# sub _MAGIC_NUMBER_MOZL4Z            { return "mozLz40\0" }

sub _WATERFOX_CURRENT_VERSION_EQUIV {
    return 68;
}    # https://github.com/MrAlex94/Waterfox/wiki/Versioning-Guidelines

sub _WATERFOX_CLASSIC_VERSION_EQUIV {
    return 56;
}    # https://github.com/MrAlex94/Waterfox/wiki/Versioning-Guidelines

my $proxy_name_regex = qr/perl_ff_m_\w+/smx;
my $tmp_name_regex   = qr/firefox_marionette_(?:remote|local)_\w+/smx;
my @sig_nums         = split q[ ], $Config{sig_num};
my @sig_names        = split q[ ], $Config{sig_name};

my $webauthn_default_authenticator_key_name = '_webauthn_authenticator';

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

sub languages {
    my ( $self, @new_languages ) = @_;
    my $pref_name = 'intl.accept_languages';
    my $script =
      'return navigator.languages'
      ; # branch.getComplexValue(arguments[0], Components.interfaces.nsIPrefLocalizedString).data';
    my $old           = $self->_context('chrome');
    my @old_languages = @{
        $self->script(
            $self->_compress_script(
                $self->_prefs_interface_preamble() . $script
            ),
            args => [$pref_name]
        )
    };
    $self->_context($old);
    if ( scalar @new_languages ) {
        $self->set_pref( $pref_name, join q[, ], @new_languages );
    }
    return @old_languages;
}

sub _setup_geo {
    my ( $self, $geo ) = @_;
    $self->set_pref( 'geo.enabled',                   1 );
    $self->set_pref( 'geo.provider.use_geoclue',      0 );
    $self->set_pref( 'geo.provider.use_corelocation', 0 );
    $self->set_pref( 'geo.provider.testing',          1 );
    $self->set_pref( 'geo.prompt.testing',            1 );
    $self->set_pref( 'geo.prompt.testing.allow',      1 );
    $self->set_pref( 'geo.security.allowinsecure',    1 );
    $self->set_pref( 'geo.wifi.scan',                 1 );
    $self->set_pref( 'permissions.default.geo',       1 );

    if ( ref $geo ) {
        if ( ( Scalar::Util::blessed($geo) ) && ( $geo->isa('URI') ) ) {
            $self->geo( $self->json($geo) );
        }
        else {
            $self->geo($geo);
        }
    }
    elsif ( $geo =~ /^(?:data|http)/smx ) {
        $self->geo( $self->json($geo) );
    }
    return $self;
}

sub geo {
    my ( $self, @parameters ) = @_;

    my $location;
    if ( scalar @parameters ) {
        $location = Firefox::Marionette::GeoLocation->new(@parameters);
    }
    if ( defined $location ) {
        $self->set_pref( 'geo.provider.network.url',
            q[data:application/json,]
              . JSON->new()->convert_blessed()->encode($location) );
        $self->set_pref( 'geo.wifi.uri',
            q[data:application/json,]
              . JSON->new()->convert_blessed()->encode($location) );
        return $self;
    }
    my $new_location =
      Firefox::Marionette::GeoLocation->new( $self->_get_geolocation() );
    return $new_location;
}

sub _get_geolocation {
    my ($self) = @_;

    my $result = $self->script( $self->_compress_script( <<'_JS_') );
return (async function() {
  function getGeo() {
    return new Promise((resolve, reject) => {
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(resolve, reject, { maximumAge: 0, enableHighAccuracy: true });
      } else {
        reject("navigator.geolocation is unavailable");
      }
    })
  };
  return await getGeo().then((response) => { let d = new Date(); return {
									"timezone_offset": d.getTimezoneOffset(),
									"latitude": response["coords"]["latitude"],
									"longitude": response["coords"]["longitude"],
									"altitude": response["coords"]["altitude"],
									"accuracy": response["coords"]["accuracy"],
									"altitudeAccuracy": response["coords"]["altitudeAccuracy"],
									"heading": response["coords"]["heading"],
									"speed": response["coords"]["speed"],
									}; }).catch((err) => { throw err.message });
})();
_JS_
    if ( ( defined $result ) && ( !ref $result ) ) {
        Firefox::Marionette::Exception->throw("javascript error: $result");
    }
    return $result;
}

sub _prefs_interface_preamble {
    my ($self) = @_;
    return <<'_JS_';    # modules/libpref/nsIPrefService.idl
let prefs = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService);
let branch = prefs.getBranch("");
_JS_
}

sub get_pref {
    my ( $self, $name ) = @_;
    my $script = <<'_JS_';
let result = [ null ];
switch (branch.getPrefType(arguments[0])) {
  case branch.PREF_STRING:
    result = [ branch.getStringPref ? branch.getStringPref(arguments[0]) : branch.getComplexValue(arguments[0], Components.interfaces.nsISupportsString).data, 'string' ];
    break;
  case branch.PREF_INT:
    result = [ branch.getIntPref(arguments[0]), 'integer' ];
    break;
  case branch.PREF_BOOL:
    result = [ branch.getBoolPref(arguments[0]), 'boolean' ];
}
return result;
_JS_
    my $old = $self->_context('chrome');
    my ( $result, $type ) = @{
        $self->script(
            $self->_compress_script(
                $self->_prefs_interface_preamble() . $script
            ),
            args => [$name]
        )
    };
    $self->_context($old);
    if ($type) {
        if ( $type eq 'integer' ) {
            $result += 0;
        }
    }
    return $result;
}

sub set_pref {
    my ( $self, $name, $value ) = @_;
    my $script = <<'_JS_';
switch (branch.getPrefType(arguments[0])) {
  case branch.PREF_INT:
    branch.setIntPref(arguments[0], arguments[1]);
    break;
  case branch.PREF_BOOL:
    branch.setBoolPref(arguments[0], arguments[1] ? true : false);
    break;
  case branch.PREF_STRING:
  default:
    if (branch.setStringPref) {
      branch.setStringPref(arguments[0], arguments[1]);
    } else {
      let newString = Components.classes["@mozilla.org/supports-string;1"].createInstance(Components.interfaces.nsISupportsString);
      newString.data = arguments[1];
      branch.setComplexValue(arguments[0], Components.interfaces.nsISupportsString, newString);
    }
}
_JS_
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script( $self->_prefs_interface_preamble() . $script ),
        args => [ $name, $value ]
    );
    $self->_context($old);
    return $self;
}

sub _clear_data_service_interface_preamble {
    my ($self) = @_;
    return <<'_JS_';    # toolkit/components/cleardata/nsIClearDataService.idl
let clearDataService = Components.classes["@mozilla.org/clear-data-service;1"].getService(Components.interfaces.nsIClearDataService);
_JS_
}

sub cache_keys {
    my ($self) = @_;
    my @names;
    foreach my $name (@Firefox::Marionette::Cache::EXPORT_OK) {
        if ( defined $self->check_cache_key($name) ) {
            push @names, $name;
        }
    }
    return @names;
}

sub check_cache_key {
    my ( $self, $name ) = @_;
    my $class = ref $self;
    defined $name
      or Firefox::Marionette::Exception->throw(
        "$class->check_cache_value() must be passed an argument.");
    $name =~ /^[[:upper:]_]+$/smx
      or Firefox::Marionette::Exception->throw(
"$class->check_cache_key() must be passed an argument consisting of uppercase characters and underscores."
      );
    my $script = <<"_JS_";
if (typeof clearDataService.$name === undefined) {
  return;
} else {
  return clearDataService.$name;
}
_JS_
    my $old    = $self->_context('chrome');
    my $result = $self->script(
        $self->_compress_script(
            $self->_clear_data_service_interface_preamble() . $script
        )
    );
    $self->_context($old);
    return $result;
}

sub clear_cache {
    my ( $self, $flags ) = @_;
    $flags = defined $flags ? $flags : Firefox::Marionette::Cache::CLEAR_ALL();
    my $script = <<'_JS_';
let argument_flags = arguments[0];
let clearCache = function(flags) {
  return new Promise((resolve) => {
    clearDataService.deleteData(flags, function() { resolve(); });
  })};
let result = (async function() {
  let awaitResult = await clearCache(argument_flags);
  return awaitResult;
})();
return arguments[0];
_JS_
    my $old    = $self->_context('chrome');
    my $result = $self->script(
        $self->_compress_script(
            $self->_clear_data_service_interface_preamble() . $script
        ),
        args => [$flags]
    );
    $self->_context($old);
    return $self;
}

sub clear_pref {
    my ( $self, $name ) = @_;
    my $script = <<'_JS_';
branch.clearUserPref(arguments[0]);
_JS_
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script( $self->_prefs_interface_preamble() . $script ),
        args => [$name]
    );
    $self->_context($old);
    return $self;
}

sub agent {
    my ( $self, @new ) = @_;
    my $pref_name = 'general.useragent.override';
    my $old_agent =
      $self->script( $self->_compress_script('return navigator.userAgent') );
    if ( ( scalar @new ) > 0 ) {
        if ( defined $new[0] ) {
            $self->set_pref( $pref_name, $new[0] );
        }
        else {
            $self->clear_pref($pref_name);
        }
    }
    return $old_agent;
}

sub _download_directory {
    my ($self) = @_;
    my $directory = $self->get_pref('browser.download.downloadDir');
    if ( my $ssh = $self->_ssh() ) {
    }
    elsif ( $OSNAME eq 'cygwin' ) {
        $directory = $self->execute( 'cygpath', '-s', '-m', $directory );
    }
    return $directory;
}

sub mime_types {
    my ($self) = @_;
    return @{ $self->{mime_types} };
}

sub download {
    my ( $self, $url, $default_timeout ) = @_;
    my $download_directory        = $self->_download_directory();
    my $quoted_download_directory = quotemeta $download_directory;
    if ( $url =~ /^$quoted_download_directory/smx ) {
        my $path = $url;
        Carp::carp( '**** DEPRECATED - The download(' . q[$]
              . 'path) method HAS BEEN REPLACED BY downloaded(' . q[$]
              . 'path) ****' );
        return $self->downloaded($path);
    }
    else {
        $default_timeout ||= _DEFAULT_DOWNLOAD_TIMEOUT();
        $default_timeout *= _MILLISECONDS_IN_ONE_SECOND();
        my $uri = URI->new($url);
        my $download_name =
          File::Temp::mktemp('firefox_marionette_download_XXXXXXXXXXX');
        my $download_path =
          File::Spec->catfile( $download_directory, $download_name );
        my $timeouts = $self->timeouts();
        $self->chrome()->timeouts(
            Firefox::Marionette::Timeouts->new(
                script    => $default_timeout,
                implicit  => $timeouts->implicit(),
                page_load => $timeouts->page_load()
            )
        );
        my $original_script = $timeouts->script();
        my $result          = $self->script(
            $self->_compress_script(
                <<'_SCRIPT_'), args => [ $uri->as_string(), $download_path ] );
let Downloads = ChromeUtils.import("resource://gre/modules/Downloads.jsm").Downloads;
return Downloads.fetch({ url: arguments[0] }, { path: arguments[1] });
_SCRIPT_
        $self->timeouts($timeouts);
        $self->content();
        my $handle;

        while ( !$handle ) {
            foreach
              my $downloaded_path ( $self->downloads($download_directory) )
            {
                if ( $downloaded_path eq $download_path ) {
                    $handle = $self->downloaded($downloaded_path);
                }
            }
        }
        return $handle;
    }
}

sub downloaded {
    my ( $self, $path ) = @_;
    my $handle;
    if ( my $ssh = $self->_ssh() ) {
        $handle = $self->_get_file_via_scp( {}, $path, 'downloaded file' );
    }
    else {
        $handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
          or Firefox::Marionette::Exception->throw(
            "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
    }
    return $handle;
}

sub _directory_listing_via_ssh {
    my ( $self, $parameters, $directory, $short ) = @_;
    my $binary    = 'ls';
    my @arguments = ( '-1', "\"$directory\"" );

    if ( $self->_remote_uname() eq 'MSWin32' ) {
        $binary    = 'dir';
        @arguments = ( '/B', "\"$directory\"" );
    }
    my $ssh_parameters = {};
    if ( $parameters->{ignore_missing_directory} ) {
        $ssh_parameters->{ignore_exit_status} = 1;
    }
    my @entries;
    my $entries =
      $self->_execute_via_ssh( $ssh_parameters, $binary, @arguments );
    if ( defined $entries ) {
        foreach my $entry ( split /\r?\n/smx, $entries ) {
            if ($short) {
                push @entries, $entry;
            }
            else {
                push @entries, $self->_remote_catfile( $directory, $entry );
            }
        }
    }
    return @entries;
}

sub _directory_listing {
    my ( $self, $parameters, $directory, $short ) = @_;
    my @entries;
    if ( my $ssh = $self->_ssh() ) {
        @entries =
          $self->_directory_listing_via_ssh( $parameters, $directory, $short );
    }
    else {
        my $handle = DirHandle->new($directory);
        if ($handle) {
            while ( defined( my $entry = $handle->read() ) ) {
                next if ( $entry eq File::Spec->updir() );
                next if ( $entry eq File::Spec->curdir() );
                if ($short) {
                    push @entries, $entry;
                }
                else {
                    push @entries, File::Spec->catfile( $directory, $entry );
                }
            }
            closedir $handle
              or Firefox::Marionette::Exception->throw(
                "Failed to close directory '$directory':$EXTENDED_OS_ERROR");
        }
        elsif ( $parameters->{ignore_missing_directory} ) {
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to open directory '$directory':$EXTENDED_OS_ERROR");
        }
    }
    return @entries;
}

sub downloading {
    my ($self) = @_;
    my $downloading = 0;
    foreach my $entry (
        $self->_directory_listing( {}, $self->_download_directory() ) )
    {
        if ( $entry =~ /[.]part$/smx ) {
            $downloading = 1;
            Carp::carp("Waiting for $entry to download");
        }
    }
    return $downloading;
}

sub downloads {
    my ( $self, $download_directory ) = @_;
    $download_directory ||= $self->_download_directory();
    return $self->_directory_listing( {}, $download_directory );
}

sub _setup_adb {
    my ( $self, $host, $port ) = @_;
    if ( !defined $port ) {
        $port = _DEFAULT_ADB_PORT();
    }
    $self->{_adb} = { host => $host, port => $port };
    return;
}

sub _read_possible_proxy_path {
    my ( $self, $path ) = @_;
    my $local_proxy_handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
      or return;
    my $result;
    my $search_contents =
      $self->_read_and_close_handle( $local_proxy_handle, $path );
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
    closedir $directory_handle
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
                $self->{_remote_uname}     = $proxy->{ssh}->{uname};
                $self->{marionette_binary} = $proxy->{ssh}->{binary};
                $self->{_initial_version}  = $proxy->{firefox}->{version};
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
                  File::Spec->catdir( $self->ssh_local_directory(), 'scp' );
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
    closedir $temp_handle
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

sub ssh_local_directory {
    my ($self) = @_;
    return $self->{_ssh_local_directory};
}

sub _setup_ssh {
    my ( $self, $host, $port, $user, $reconnect ) = @_;
    if ($reconnect) {
        $self->_setup_ssh_with_reconnect( $host, $port, $user );
    }
    else {
        my $ssh_local_directory = File::Temp->newdir(
            CLEANUP  => 0,
            TEMPLATE => File::Spec->catdir(
                File::Spec->tmpdir(), 'perl_ff_m_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to create temporary directory:$EXTENDED_OS_ERROR");
        $self->{_ssh_local_directory} = $ssh_local_directory->dirname();
        my $local_scp_directory =
          File::Spec->catdir( $self->ssh_local_directory(), 'scp' );
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
              File::Spec->catfile( $self->ssh_local_directory(),
                'control.sock' );
        }
    }
    $self->_initialise_remote_uname();
    if ( ( defined $self->_visible() ) && ( $self->_visible() eq 'local' ) ) {
        if ( !$self->_get_remote_environment_variable_via_ssh('DISPLAY') ) {
            Firefox::Marionette::Exception->throw(
                $self->_ssh_address() . ' is not allowing X11 Forwarding' );
        }

    }
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

sub images {
    my ( $self, $from ) = @_;
    return grep { $_->url() }
      map       { Firefox::Marionette::Image->new($_) }
      $self->has( '//*[self::img or self::input]', undef, $from );
}

sub links {
    my ( $self, $from ) = @_;
    return map { Firefox::Marionette::Link->new($_) } $self->has(
'//*[self::a or self::area or self::frame or self::iframe or self::meta]',
        undef, $from
    );
}

sub _get_marionette_parameter {
    my ( $self, %parameters ) = @_;
    foreach my $deprecated_key (qw(firefox_binary firefox marionette)) {
        if ( $parameters{$deprecated_key} ) {
            Carp::carp(
"**** DEPRECATED - $deprecated_key HAS BEEN REPLACED BY binary ****"
            );
            $self->{marionette_binary} = $parameters{$deprecated_key};
        }
    }
    if ( $parameters{binary} ) {
        $self->{marionette_binary} = $parameters{binary};
    }
    return;
}

sub _store_restart_parameters {
    my ( $self, %parameters ) = @_;
    $self->{_restart_parameters} = { restart => 1 };
    foreach my $key ( sort { $a cmp $b } keys %parameters ) {
        next if ( $key eq 'profile' );
        next if ( $key eq 'capabilities' );
        next if ( $key eq 'timeout' );
        next if ( $key eq 'geo' );
        $self->{_restart_parameters}->{$key} = $parameters{$key};
    }
    return;
}

sub _init {
    my ( $class, %parameters ) = @_;
    my $self = bless {}, $class;
    $self->_store_restart_parameters(%parameters);
    $self->{last_message_id}    = 0;
    $self->{creation_pid}       = $PROCESS_ID;
    $self->{sleep_time_in_ms}   = $parameters{sleep_time_in_ms};
    $self->{force_scp_protocol} = $parameters{scp};
    $self->{visible}            = $parameters{visible};
    $self->{force_webauthn}     = $parameters{webauthn};
    $self->{geo}                = $parameters{geo};

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
    $self->{ssh_via_host}    = $parameters{via};
    $self->{reconnect_index} = $parameters{index};

    $self->_get_marionette_parameter(%parameters);
    if ( $parameters{console} ) {
        $self->{console} = 1;
    }

    if ( defined $parameters{adb} ) {
        $self->_setup_adb( $parameters{adb}, $parameters{port} );
    }
    if ( defined $parameters{host} ) {
        if ( $OSNAME eq 'MSWin32' ) {
            $parameters{user} ||= Win32::LoginName();
        }
        else {
            $parameters{user} ||= getpwuid $EFFECTIVE_USER_ID;
        }
        if ( $parameters{host} =~ s/:(\d+)$//smx ) {
            $parameters{port} = $1;
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
    return $port || _DEFAULT_PORT();
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

sub _get_local_name_regex {
    my ($self) = @_;
    my $local_name_regex = qr/firefox_marionette_local_/smx;
    if ( $self->{reconnect_index} ) {
        my $quoted_index = quotemeta $self->{reconnect_index};
        $local_name_regex = qr/${local_name_regex}${quoted_index}\-/smx;
    }
    $local_name_regex = qr/${local_name_regex}\w+/smx;
    return $local_name_regex;
}

sub _get_local_reconnect_pid {
    my ($self)         = @_;
    my $temp_directory = File::Spec->tmpdir();
    my $temp_handle    = DirHandle->new($temp_directory)
      or Firefox::Marionette::Exception->throw(
        "Failed to open directory '$temp_directory':$EXTENDED_OS_ERROR");
    my $alive_pid;
    my $local_name_regex = $self->_get_local_name_regex();

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
            $self->_setup_profile();
        }
    }
    closedir $temp_handle
      or Firefox::Marionette::Exception->throw(
        "Failed to close directory '$temp_directory':$EXTENDED_OS_ERROR");
    return $alive_pid;
}

sub _setup_profile {
    my ($self) = @_;
    if ( $self->{profile_name} ) {
        $self->{_profile_directory} =
          Firefox::Marionette::Profile->directory( $self->{profile_name} );
        $self->{profile_path} =
          File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
    }
    else {
        $self->{_profile_directory} =
          File::Spec->catfile( $self->{_root_directory}, 'profile' );
        $self->{_download_directory} =
          File::Spec->catfile( $self->{_root_directory}, 'downloads' );
        $self->{profile_path} =
          File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
    }
    return;
}

sub _reconnect {
    my ( $self, %parameters ) = @_;
    if ( $parameters{profile_name} ) {
        $self->{profile_name} = $parameters{profile_name};
    }
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
"Failed to re-connect to Firefox process at '$host:$port':$EXTENDED_OS_ERROR"
      );
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

sub profile_directory {
    my ($self) = @_;
    return $self->{_profile_directory};
}

sub _pk11_tokendb_interface_preamble {
    my ($self) = @_;
    return <<'_JS_';    # security/manager/ssl/nsIPK11Token.idl
let pk11db = Components.classes["@mozilla.org/security/pk11tokendb;1"].getService(Components.interfaces.nsIPK11TokenDB);
let token = pk11db.getInternalKeyToken();
_JS_
}

sub pwd_mgr_needs_login {
    my ($self) = @_;
    my $script = <<'_JS_';
if (('hasPassword' in token) && (!token.hasPassword)) {
  return false;
} else if (('needsLogin' in token) && (!token.needsLogin())) {
  return false;
} else if (token.isLoggedIn()) {
  return false;
} else {
  return true;
}
_JS_
    my $old    = $self->_context('chrome');
    my $result = $self->script(
        $self->_compress_script(
            $self->_pk11_tokendb_interface_preamble() . $script
        )
    );
    $self->_context($old);
    return $result;
}

sub pwd_mgr_logout {
    my ($self) = @_;
    my $script = <<'_JS_';
token.logoutAndDropAuthenticatedResources();
_JS_
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script(
            $self->_pk11_tokendb_interface_preamble() . $script
        )
    );
    $self->_context($old);
    return $self;
}

sub pwd_mgr_lock {
    my ( $self, $password ) = @_;
    if ( !defined $password ) {
        Firefox::Marionette::Exception->throw(
            'Primary Password has not been provided');
    }
    my $script = <<'_JS_';
if (token.needsUserInit) {
  token.initPassword(arguments[0]);
} else {
  token.changePassword("",arguments[0]);
}
_JS_
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script(
            $self->_pk11_tokendb_interface_preamble() . $script
        ),
        args => [$password]
    );
    $self->_context($old);
    return $self;
}

sub pwd_mgr_login {
    my ( $self, $password ) = @_;
    if ( !defined $password ) {
        Firefox::Marionette::Exception->throw(
            'Primary Password has not been provided');
    }
    my $script = <<'_JS_';
if (token.checkPassword(arguments[0])) {
  return true;
} else {
  return false;
}
_JS_
    my $old = $self->_context('chrome');
    if (
        $self->script(
            $self->_compress_script(
                $self->_pk11_tokendb_interface_preamble() . $script
            ),
            args => [$password]
        )
      )
    {
        $self->_context($old);
    }
    else {
        $self->_context($old);
        Firefox::Marionette::Exception->throw('Incorrect Primary Password');
    }
    return $self;
}

sub _bookmark_interface_preamble {
    my ($self) = @_;

    # toolkit/components/places/nsITaggingService.idl
    # netwerk/base/NetUtil.sys.mjs
    # toolkit/components/places/PlacesUtils.sys.mjs
    return <<'_JS_';    # toolkit/components/places/Bookmarks.sys.mjs
let bookmarks = ChromeUtils.import("resource://gre/modules/Bookmarks.jsm");
let placesUtils = ChromeUtils.import("resource://gre/modules/PlacesUtils.jsm");
let netUtil = ChromeUtils.import("resource://gre/modules/NetUtil.jsm");
let taggingSvc = Components.classes["@mozilla.org/browser/tagging-service;1"].getService(Components.interfaces.nsITaggingService);
_JS_
}

sub _get_bookmark_mapping {
    my ($self) = @_;
    my %mapping = (
        url           => 'url',
        guid          => 'guid',
        parent_guid   => 'parentGuid',
        index         => 'index',
        guid_prefix   => 'guidPrefix',
        icon_url      => 'iconUri',
        icon          => 'icon',
        tags          => 'tags',
        type          => 'typeCode',
        date_added    => 'dateAdded',
        last_modified => 'lastModified',
    );
    return %mapping;
}

sub _map_bookmark_parameter {
    my ( $self, $parameter ) = @_;
    if ( ref $parameter ) {
        my %mapping = $self->_get_bookmark_mapping();

        foreach my $key ( sort { $a cmp $b } keys %mapping ) {
            if ( exists $parameter->{$key} ) {
                $parameter->{ $mapping{$key} } = delete $parameter->{$key};
                if (   ( $key eq 'icon_url' )
                    || ( $key eq 'icon' )
                    || ( $key eq 'url' ) )
                {
                    $parameter->{ $mapping{$key} } =
                      ref $parameter->{$key}
                      ? $parameter->{$key}->as_string()
                      : $parameter->{$key};
                }
            }
        }
    }
    return $parameter;
}

sub _get_bookmark {
    my ( $self, $parameter ) = @_;
    $parameter = $self->_map_bookmark_parameter($parameter);
    my $old    = $self->_context('chrome');
    my $result = $self->script(
        $self->_compress_script(
            $self->_bookmark_interface_preamble()
              . <<'_JS_'), args => [$parameter] );
return (async function(guidOrInfo) {
  let bookmark = await bookmarks.Bookmarks.fetch(guidOrInfo);
  if (bookmark) {
    for(let name of [ "dateAdded", "lastModified" ]) {
      bookmark[name] = Math.floor(bookmark[name] / 1000);
    }
  }
  if ((bookmark) && ("url" in bookmark)) {
    let keyword = await placesUtils.PlacesUtils.keywords.fetch({ "url": bookmark["url"] });
    if (keyword) {
      bookmark["keyword"] = keyword["keyword"];
    }
    let url = netUtil.NetUtil.newURI(bookmark["url"]);
    bookmark["tags"] = await placesUtils.PlacesUtils.tagging.getTagsForURI(url);

    let addFavicon = function(pageUrl) {
      return new Promise((resolve, reject) => {
        PlacesUtils.favicons.getFaviconDataForPage(
          pageUrl,
          function (pageUrl, dataLen, data, mimeType, size) {
            resolve([ pageUrl, dataLen, data, mimeType, size ]);
          }
        );
      })};
    let awaitResult = await addFavicon(placesUtils.PlacesUtils.toURI(bookmark["url"]));
    if (awaitResult[0]) {
      bookmark["iconUrl"] = awaitResult[0].spec;
    }
    let iconAscii = btoa(String.fromCharCode(...new Uint8Array(awaitResult[2])));
    if (iconAscii) {
      bookmark["icon"] = "data:" + awaitResult[3] + ";base64," + iconAscii;
    }
  }
  return bookmark;
})(arguments[0]);
_JS_
    $self->_context($old);
    my $bookmark;
    if ( defined $result ) {
        $bookmark = Firefox::Marionette::Bookmark->new( %{$result} );
    }
    return $bookmark;
}

sub bookmarks {
    my ( $self, @parameters ) = @_;
    my $parameter;
    if ( scalar @parameters >= 2 ) {
        my %parameters = @parameters;
        $parameter = \%parameters;
    }
    else {
        $parameter = shift @parameters;
    }
    if ( !defined $parameter ) {
        $parameter = {};
    }
    $parameter = $self->_map_bookmark_parameter($parameter);
    my $old       = $self->_context('chrome');
    my @bookmarks = map { $self->_get_bookmark( $_->{guid} ) } @{
        $self->script(
            $self->_compress_script(
                $self->_bookmark_interface_preamble()
                  . <<'_JS_'), args => [$parameter] ) };
return bookmarks.Bookmarks.search(arguments[0]);
_JS_
    $self->_context($old);
    return @bookmarks;
}

sub add_bookmark {
    my ( $self, $bookmark ) = @_;
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script(
            $self->_bookmark_interface_preamble()
              . <<'_JS_'), args => [$bookmark] );
for(let name of [ "dateAdded", "lastModified" ]) {
  if (arguments[0][name]) {
    arguments[0][name] = new Date(parseInt(arguments[0][name] + "000", 10));
  }
}
if (arguments[0]["tags"]) {
  let tags = arguments[0]["tags"];
  delete arguments[0]["tags"];
  let url = netUtil.NetUtil.newURI(arguments[0]["url"]);
  taggingSvc.tagURI(url, tags);
}
if (arguments[0]["keyword"]) {
  let keyword = arguments[0]["keyword"];
  delete arguments[0]["keyword"];
  let url = arguments[0]["url"];
  placesUtils.PlacesUtils.keywords.insert({ "url": url, "keyword": keyword });
}
let bookmarkStatus = (async function(bookmarkArguments) {
  let exists = await bookmarks.Bookmarks.fetch({ "guid": bookmarkArguments["guid"] });
  let bookmark;
  if (exists) {
    bookmarkArguments["index"] = exists["index"];
    bookmark = bookmarks.Bookmarks.update(bookmarkArguments);
  } else {
    bookmark = bookmarks.Bookmarks.insert(bookmarkArguments);
  }
  let result = await bookmark;
  if (bookmarkArguments["url"]) {
    let iconUrl = bookmarkArguments["iconUrl"];
    if (!iconUrl) {
      iconUrl = 'fake-favicon-uri:' + bookmarkArguments["url"];
    }
    let url = netUtil.NetUtil.newURI(bookmarkArguments["url"]);
    let rIconUrl = netUtil.NetUtil.newURI(iconUrl);
    if (bookmarkArguments["icon"]) {
      let icon = bookmarkArguments["icon"];
      placesUtils.PlacesUtils.favicons.replaceFaviconDataFromDataURL(
        rIconUrl,
        icon,
      );
      let iconResult = placesUtils.PlacesUtils.favicons.setAndFetchFaviconForPage(
          url,
          rIconUrl,
          false,
          placesUtils.PlacesUtils.favicons.FAVICON_LOAD_NON_PRIVATE,
          null,
          Services.scriptSecurityManager.getSystemPrincipal()
        );
    } else {
      let iconResult = placesUtils.PlacesUtils.favicons.setAndFetchFaviconForPage(
        url,
        rIconUrl,
        true,
        placesUtils.PlacesUtils.favicons.FAVICON_LOAD_NON_PRIVATE,
        null,
        Services.scriptSecurityManager.getSystemPrincipal()
      );
    }
  }
  return bookmark;
})(arguments[0]);
return bookmarkStatus;
_JS_
    $self->_context($old);
    return $self;
}

sub delete_bookmark {
    my ( $self, $bookmark ) = @_;
    my $guid = $bookmark->guid();
    my $old  = $self->_context('chrome');
    $self->script(
        $self->_compress_script(
            $self->_bookmark_interface_preamble()
              . <<'_JS_'), args => [$guid] );
return bookmarks.Bookmarks.remove(arguments[0]);
_JS_
    $self->_context($old);
    return $self;
}

sub _generate_history_guid {
    my ($self) = @_;

    # from GenerateGUID in ./toolkit/components/places/Helpers.cpp
    my $guid = MIME::Base64::encode_base64(
        Crypt::URandom::urandom( _SHORT_GUID_BYTES() ) );
    $guid =~ s/\//-/smxg;
    $guid =~ s/[+]/_/smxg;
    chomp $guid;
    return $guid;
}

sub import_bookmarks {
    my ( $self, $path ) = @_;
    my $read_handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
    binmode $read_handle;
    my $contents;
    my $result;
    while ( $result =
        $read_handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() ) )
    {
        $contents .= $buffer;
    }
    my $default_menu_title = q[menu];
    defined $result
      or Firefox::Marionette::Exception->throw(
        "Failed to read from '$path':$EXTENDED_OS_ERROR");
    my $quoted_header_regex = quotemeta <<'_HTML_';
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
_HTML_
    $quoted_header_regex =~ s/\\\r?\n/\\s+/smxg;
    my $title_regex  = qr/[<]TITLE[>]Bookmarks[<]\/TITLE[>]\s+/smx;
    my $header_regex = qr/[<]H1[>]Bookmarks(?:[ ]Menu)?[<]\/H1[>]\s+/smx;
    my $list_regex   = qr/[<]DL[>][<]p[>]\s*/smx;

    if ( $contents =~ s/\A\s*$quoted_header_regex\s*//smx ) {
        $contents =~ s/\A\s*<meta[^>]+><\/meta>\s*//smx;
        $contents =~ s/\A$title_regex$header_regex$list_regex//smx;
        my %mapping    = $self->_get_bookmark_mapping();
        my $processing = 1;
        my $index      = 0;
        my $json       = {
            title          => q[],
            index          => $index++,
            $mapping{type} => Firefox::Marionette::Bookmark::FOLDER(),
            guid           => Firefox::Marionette::Bookmark::ROOT(),
            children       => [],
        };
        my @folders;
        push @folders, $json;
        my $folder_name_regex = qr/(UNFILED_BOOKMARKS|PERSONAL_TOOLBAR)/smx;
        my $folder_regex =
            qr/\s*[<]DT[>]/smx
          . qr/[<]H3(?:[ ]ADD_DATE="(\d+)")?(?:[ ]LAST_MODIFIED="(\d+)")?/smx
          . qr/(?:[ ]${folder_name_regex}_FOLDER="true")?[>]/smx
          . qr/([^<]+)\s*<\/H3>/smx;
        my $bookmark_regex =
            qr/\s*[<]DT[>][<]A[ ]HREF="([^"]+)"[ ]/smx
          . qr/ADD_DATE="(\d+)"(?:[ ]LAST_MODIFIED="(\d+)")?/smx
          . qr/(?:[ ]ICON_URI="([^"]+)")?(?:[ ]ICON="([^"]+)")?/smx
          . qr/(?:[ ]SHORTCUTURL="([^"]+)")?(?:[ ]TAGS="([^"]+)")?[>]/smx
          . qr/([^<]+)[<]\/A[>]\s*/smx;

        while ($processing) {
            $processing = 0;
            if ( $contents =~ s/\A$folder_regex//smx ) {
                my ( $add_date, $last_modified, $type_of_folder, $text ) =
                  ( $1, $2, $3, $4 );
                $processing = 1;
                if ( !$type_of_folder ) {
                    my $implied_menu_folder = {
                        title =>
                          Encode::decode( 'UTF-8', $default_menu_title, 1 ),
                        index          => $index++,
                        $mapping{type} =>
                          Firefox::Marionette::Bookmark::FOLDER(),
                        guid     => Firefox::Marionette::Bookmark::MENU(),
                        children => [],
                    };
                    push @{ $folders[-1]->{children} }, $implied_menu_folder;
                    push @folders,                      $implied_menu_folder;
                }
                my $folder_name = $text;
                my $folder      = {
                    title => Encode::decode( 'UTF-8', $folder_name, 1 ),
                    index => $index++,
                    $mapping{type} => Firefox::Marionette::Bookmark::FOLDER(),
                    (
                        $type_of_folder
                        ? (
                            $type_of_folder eq 'PERSONAL_TOOLBAR'
                            ? ( guid =>
                                  Firefox::Marionette::Bookmark::TOOLBAR() )
                            : ( guid =>
                                  Firefox::Marionette::Bookmark::UNFILED() )
                          )
                        : ()
                    ),
                    $mapping{date_added} =>
                      $self->_fix_bookmark_date_from_html($add_date),
                    (
                        $last_modified
                        ? (
                            $mapping{last_modified} =>
                              $self->_fix_bookmark_date_from_html(
                                $last_modified),
                          )
                        : ()
                    ),
                    children => [],
                };
                push @{ $folders[-1]->{children} }, $folder;
                push @folders,                      $folder;
            }
            if ( $contents =~ s/\A\s*[<]DL[>][<]p[>]\s*//smx ) {
                $processing = 1;
            }
            if ( $contents =~ s/\A$bookmark_regex//smx ) {
                my ( $link, $add_date, $last_modified, $icon_uri, $icon,
                    $keyword, $tags, $text )
                  = ( $1, $2, $3, $4, $5, $6, $7, $8 );
                my $link_name = $text;
                $processing = 1;
                my $bookmark = {
                    title => Encode::decode( 'UTF-8', $link_name, 1 ),
                    uri   => $link,
                    $mapping{icon_url} => $icon_uri,
                    icon               => $icon,
                    index              => $index++,
                    $mapping{type} => Firefox::Marionette::Bookmark::BOOKMARK(),
                    $mapping{date_added} =>
                      $self->_fix_bookmark_date_from_html($add_date),
                    $mapping{last_modified} =>
                      $self->_fix_bookmark_date_from_html($last_modified),
                    tags    => Encode::decode( 'UTF-8', $tags,    1 ),
                    keyword => Encode::decode( 'UTF-8', $keyword, 1 ),
                };
                push @{ $folders[-1]->{children} }, $bookmark;
            }
            if ( $contents =~ s/\A\s*[<]HR[>]\s*//smx ) {
                $processing = 1;
                my $separator = {
                    index          => $index++,
                    $mapping{type} =>
                      Firefox::Marionette::Bookmark::SEPARATOR(),
                };
                push @{ $folders[-1]->{children} }, $separator;
            }
            if ( $contents =~ s/\A\s*[<]\/DL[>](?:[<]p[>])?\s*//smx ) {
                $processing = 1;
                pop @folders;
            }
        }
        if ($contents) {
            Firefox::Marionette::Exception->throw(
                'Unrecognised format for bookmark import');
        }
        $json = $self->_find_existing_guids($json);
        $self->_import_bookmark_json_children( {}, $json );
    }
    else {
        my $json = JSON::decode_json($contents);
        $self->_import_bookmark_json_children( {}, $json );
    }
    return $self;
}

sub _fix_bookmark_date_from_html {
    my ( $self, $date ) = @_;
    if ($date) {
        $date .= '000000';
    }
    return $date;
}

sub _assign_guid_for_existing_child {
    my ( $self, $result, $child, %mapping ) = @_;
    if ( $result->type() == $child->{ $mapping{type} } ) {
        if ( $result->type() == Firefox::Marionette::Bookmark::FOLDER() ) {
            if ( $result->title() eq $child->{title} ) {
                $child->{guid} = $result->guid();
            }
        }
        elsif ( $result->type() == Firefox::Marionette::Bookmark::BOOKMARK() ) {
            if ( $result->url() eq $child->{uri} ) {
                $child->{guid} = $result->guid();
            }
        }
        else {    # Firefox::Marionette::Bookmark::SEPARATOR()
            $child->{guid} = $result->guid();
        }
    }
    return;
}

sub _find_existing_guids {
    my ( $self, $json ) = @_;
    foreach my $child ( @{ $json->{children} } ) {
        if ( $child->{guid} ) {
        }
        else {
            my $index   = 0;
            my %mapping = $self->_get_bookmark_mapping();
            while ( ( !$child->{guid} ) && ( defined $index ) ) {
                my $result = $self->_get_bookmark(
                    { parent_guid => $json->{guid}, index => $index } );
                if ( defined $result ) {
                    $self->_assign_guid_for_existing_child( $result, $child,
                        %mapping );
                    $index += 1;
                }
                else {
                    $child->{guid} = $self->_generate_history_guid();
                    $index = undef;
                }
            }
        }
        if ( $child->{children} ) {
            $self->_find_existing_guids($child);
        }
    }
    return $json;
}

sub _import_bookmark_json_children {
    my ( $self, $grand_parent, $parent ) = @_;
    my $date_added = $parent->{dateAdded};
    if ( defined $date_added ) {
        $date_added =~ s/\d{6}$//smx;
        $date_added += 0;
    }
    my $last_modified = $parent->{lastModified};
    if ( defined $last_modified ) {
        $last_modified =~ s/\d{6}$//smx;
        $last_modified += 0;
    }
    my $bookmark = Firefox::Marionette::Bookmark->new(
        guid          => $parent->{guid},
        parent_guid   => $grand_parent->{guid},
        title         => $parent->{title},
        url           => $parent->{uri},
        date_added    => $date_added,
        last_modified => $last_modified,
        type          => $parent->{typeCode},
        icon_url      => $parent->{iconUri},
        icon          => $parent->{icon},
        (
            $parent->{tags}
            ? ( tags => [ split /\s*,\s*/smx, $parent->{tags} ] )
            : ()
        ),
        keyword => $parent->{keyword},
    );
    if (   ( $bookmark->guid() )
        && ( !$self->_get_bookmark( $bookmark->guid() ) ) )
    {
        $self->add_bookmark($bookmark);
    }
    elsif ( $bookmark->url() ) {
        my $found;
        foreach
          my $existing ( $self->bookmarks( $bookmark->url()->as_string() ) )
        {
            if ( $existing->url() eq $bookmark->url() ) {
                $found = 1;
            }
        }
        if ( !$found ) {
            $self->add_bookmark($bookmark);
        }
    }
    foreach my $child ( @{ $parent->{children} } ) {
        $self->_import_bookmark_json_children( $parent, $child );
    }
    return $self;
}

sub _import_profile_paths {
    my ( $self, %parameters ) = @_;
    if ( $parameters{import_profile_paths} ) {
        foreach my $path ( @{ $parameters{import_profile_paths} } ) {
            my ( $volume, $directories, $name ) = File::Spec->splitpath($path);
            my $read_handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
              or Firefox::Marionette::Exception->throw(
                "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
            binmode $read_handle;
            if ( $self->_ssh() ) {
                $self->_put_file_via_scp(
                    $read_handle,
                    $self->_remote_catfile(
                        $self->{_profile_directory}, $name
                    ),
                    $name
                );
            }
            else {
                my $write_path =
                  File::Spec->catfile( $self->{_profile_directory}, $name );
                my $write_handle = FileHandle->new(
                    $write_path,
                    Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
                    Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
                  )
                  or Firefox::Marionette::Exception->throw(
"Failed to open '$write_path' for writing:$EXTENDED_OS_ERROR"
                  );
                binmode $write_handle;
                my $result;
                while ( $result =
                    $read_handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() )
                  )
                {
                    print {$write_handle} $buffer
                      or Firefox::Marionette::Exception->throw(
                        "Failed to write to '$write_path':$EXTENDED_OS_ERROR");
                }
                defined $result
                  or Firefox::Marionette::Exception->throw(
                    "Failed to read from '$path':$EXTENDED_OS_ERROR");
                close $write_handle
                  or Firefox::Marionette::Exception->throw(
                    "Failed to close '$write_path':$EXTENDED_OS_ERROR");
            }
            close $read_handle
              or Firefox::Marionette::Exception->throw(
                "Failed to close '$path':$EXTENDED_OS_ERROR");
        }
    }
    return;
}

sub webauthn_authenticator {
    my ($self) = @_;
    return $self->{$webauthn_default_authenticator_key_name};
}

sub add_webauthn_authenticator {
    my ( $self, %parameters ) = @_;
    if ( !defined $parameters{protocol} ) {
        $parameters{protocol} = 'ctap2';
    }
    if ( !defined $parameters{transport} ) {
        $parameters{transport} = 'internal';
    }
    foreach my $key (
        qw(
        has_resident_key
        is_user_consenting
        is_user_verified
        has_user_verification
        )
      )
    {
        $parameters{$key} = $self->_translate_to_json_boolean(
            $self->_default_to_true( $parameters{$key} ) );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebAuthn:AddVirtualAuthenticator'),
            {
                protocol            => $parameters{protocol},
                transport           => $parameters{transport},
                hasResidentKey      => $parameters{has_resident_key},
                hasUserVerification => $parameters{has_user_verification},
                isUserConsenting    => $parameters{is_user_consenting},
                isUserVerified      => $parameters{is_user_verified},
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return Firefox::Marionette::WebAuthn::Authenticator->new(
        id => $self->_response_result_value($response),
        %parameters
    );
}

sub _default_to_true {
    my ( $self, $boolean ) = @_;
    if ( !defined $boolean ) {
        $boolean = 1;
    }
    return $boolean;
}

sub webauthn_set_user_verified {
    my ( $self, $boolean, $parameter_authenticator ) = @_;
    my $authenticator = $self->_get_webauthn_authenticator(
        authenticator => $parameter_authenticator );
    $boolean =
      $self->_translate_to_json_boolean( $self->_default_to_true($boolean) );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebAuthn:SetUserVerified'),
            {
                authenticatorId => $authenticator->id(),
                isUserVerified  => $boolean,
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub delete_webauthn_authenticator {
    my ( $self, $parameter_authenticator ) = @_;
    my $authenticator = $self->_get_webauthn_authenticator(
        authenticator => $parameter_authenticator );

    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebAuthn:RemoveVirtualAuthenticator'),
            {
                authenticatorId => $authenticator->id(),
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    if (   ( $self->webauthn_authenticator() )
        && ( $self->webauthn_authenticator()->id() == $authenticator->id() ) )
    {
        delete $self->{$webauthn_default_authenticator_key_name};
    }
    return $self;
}

sub add_webauthn_credential {
    my ( $self, %parameters ) = @_;
    foreach my $key (
        qw(
        is_resident
        )
      )
    {
        $parameters{$key} = $self->_translate_to_json_boolean(
            $self->_default_to_true( $parameters{$key} ) );
    }
    if ( !defined $parameters{id} ) {
        my $credential_id = MIME::Base64::encode_base64url(
            Crypt::URandom::urandom( _CREDENTIAL_ID_LENGTH() ) );
        $parameters{id} = $credential_id;
    }
    if ( defined $parameters{user} ) {
        $parameters{user} =
          MIME::Base64::encode_base64url( $parameters{user} );
    }
    if ( !defined $parameters{private_key} ) {
        $parameters{private_key} = {};
    }
    if ( ref $parameters{private_key} eq 'HASH' ) {
        my $script = <<'_JS_';
let privateKeyArguments = {};
if (arguments[0]["name"]) {
  privateKeyArguments["name"] = arguments[0]["name"];
} else {
  privateKeyArguments["name"] = "RSA-PSS";
}
if ((privateKeyArguments["name"] == "RSA-PSS") || (privateKeyArguments["name"] == "RSASSA-PKCS1-v1_5")) {
  privateKeyArguments["modulusLength"] = arguments[0]["size"] || 8192;
  privateKeyArguments["publicExponent"] = new Uint8Array([1, 0, 1]);
  privateKeyArguments["hash"] = arguments[0]["hash"] || "SHA-512";
} else if ((privateKeyArguments["name"] == "ECDSA") || (privateKeyArguments["name"] == "ECDH")) {
  privateKeyArguments["namedCurve"] = arguments[0]["curve"] || "P-384";
}
let privateKey = (async function() {
  let keyPair = await window.crypto.subtle.generateKey(
    privateKeyArguments,
    true,
    ["sign"]
  );
  let exportedKey = await window.crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  let CHUNK_SZ = 0x8000;
  let c = [];
  let array = new Uint8Array(exportedKey);
  for (let i = 0; i < array.length; i += CHUNK_SZ) {
    c.push(String.fromCharCode.apply(null, array.subarray(i, i + CHUNK_SZ)));
  }
  let b64Key = window.btoa(c.join(""));
  let urlSafeKey = b64Key.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  return urlSafeKey;
})();
return privateKey;
_JS_
        my $old = $self->_context('chrome');
        $parameters{private_key} = $self->script(
            $self->_compress_script($script),
            args => [ $parameters{private_key} ]
        );
        $self->_context($old);
    }
    if ( !defined $parameters{sign_count} ) {
        $parameters{sign_count} = 0;
    }
    my $authenticator         = $self->_get_webauthn_authenticator(%parameters);
    my %credential_parameters = (
        authenticatorId      => $authenticator->id(),
        credentialId         => $parameters{id},
        isResidentCredential => $parameters{is_resident},
        rpId                 => $parameters{host},
        privateKey           => $parameters{private_key},
        signCount            => $parameters{sign_count},
        userHandle           => $parameters{user},
    );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id, $self->_command('WebAuthn:AddCredential'),
            \%credential_parameters,
        ]
    );
    if ( defined $credential_parameters{userHandle} ) {
        $credential_parameters{userHandle} =
          MIME::Base64::decode_base64url( $credential_parameters{userHandle} );
    }
    my $response = $self->_get_response($message_id);
    return Firefox::Marionette::WebAuthn::Credential->new(
        %credential_parameters);
}

sub _get_webauthn_authenticator {
    my ( $self, %parameters ) = @_;
    my $authenticator;
    if ( $parameters{authenticator} ) {
        $authenticator = $parameters{authenticator};
    }
    else {
        $authenticator = $self->webauthn_authenticator();
    }
    return $authenticator;
}

sub webauthn_credentials {
    my ( $self, $parameter_authenticator ) = @_;
    my $authenticator = $self->_get_webauthn_authenticator(
        authenticator => $parameter_authenticator );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebAuthn:GetCredentials'),
            {
                authenticatorId => $authenticator->id(),
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return map { Firefox::Marionette::WebAuthn::Credential->new( %{$_} ) }
      map      { $self->_decode_credential_user_handle($_) }
      @{ $self->_response_result_value($response) };
}

sub _decode_credential_user_handle {
    my ( $self, $credential ) = @_;
    if ( $credential->{userHandle} eq q[] ) {
        $credential->{userHandle} = undef;
    }
    else {
        $credential->{userHandle} =
          MIME::Base64::decode_base64url( $credential->{userHandle} );
    }
    return $credential;
}

sub delete_webauthn_all_credentials {
    my ( $self, $parameter_authenticator ) = @_;
    my $authenticator = $self->_get_webauthn_authenticator(
        authenticator => $parameter_authenticator );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebAuthn:RemoveAllCredentials'),
            {
                authenticatorId => $authenticator->id(),
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub delete_webauthn_credential {
    my ( $self, $credential, $parameter_authenticator ) = @_;
    my $authenticator = $self->_get_webauthn_authenticator(
        authenticator => $parameter_authenticator );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(),
            $message_id,
            $self->_command('WebAuthn:RemoveCredential'),
            {
                authenticatorId => $authenticator->id(),
                credentialId    => $credential->id(),
            }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub _login_interface_preamble {
    my ($self) = @_;

    return <<'_JS_';    # toolkit/components/passwordmgr/nsILoginManager.idl
let loginManager = Components.classes["@mozilla.org/login-manager;1"].getService(Components.interfaces.nsILoginManager);
_JS_
}

sub fill_login {
    my ($self) = @_;

    my $found;
    my $browser_uri = URI->new( $self->uri() );
  FORM: foreach my $form ( $self->find_tag('form') ) {
        my $action     = $form->attribute('action');
        my $action_uri = URI->new_abs( $action, $browser_uri );
        my $old        = $self->_context('chrome');
        my @logins     = $self->_translate_firefox_logins(
            @{
                $self->script(
                    $self->_compress_script(
                        $self->_login_interface_preamble()
                          . <<"_JS_"), args => [ $browser_uri->scheme() . '://' . $browser_uri->host(), $action_uri->scheme() . '://' . $action_uri->host() ] ) } );
try {
    return loginManager.findLogins(arguments[0], arguments[1], null);
} catch (e) {
    console.log("Unable to use modern loginManager.findLogins methods:" + e);
    return loginManager.findLogins({}, arguments[0], arguments[1], null);
}
_JS_
        $self->_context($old);
        foreach my $login (@logins) {
            if (
                ( my $user_field = $form->has_name( $login->user_field ) )
                && ( my $password_field =
                    $form->has_name( $login->password_field ) )
              )
            {
                $user_field->clear();
                $password_field->clear();
                $user_field->type( $login->user() );
                $password_field->type( $login->password() );
                $found = 1;
                last FORM;
            }
        }
    }
    if ( !$found ) {
        Firefox::Marionette::Exception->throw(
            "Unable to fill in form on $browser_uri");
    }
    return $self;
}

sub delete_login {
    my ( $self, $login ) = @_;
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script(
            $self->_login_interface_preamble()
              . $self->_define_login_info_from_blessed_user(
                'loginInfo', $login
              )
              . <<"_JS_"), args => [$login] );
loginManager.removeLogin(loginInfo);
_JS_
    $self->_context($old);
    return $self;
}

sub delete_logins {
    my ($self) = @_;
    my $old = $self->_context('chrome');
    $self->script(
        $self->_compress_script(
            $self->_login_interface_preamble() . <<"_JS_") );
loginManager.removeAllLogins();
_JS_
    $self->_context($old);
    return $self;
}

sub _define_login_info_from_blessed_user {
    my ( $self, $variable_name, $login ) = @_;
    return <<"_JS_";
let $variable_name = Components.classes["\@mozilla.org/login-manager/loginInfo;1"].createInstance(Components.interfaces.nsILoginInfo);
$variable_name.init(arguments[0].host, ("realm" in arguments[0] && arguments[0].realm !== null ? null : arguments[0].origin || ""), arguments[0].realm, arguments[0].user, arguments[0].password, "user_field" in arguments[0] && arguments[0].user_field !== null ? arguments[0].user_field : "", "password_field" in arguments[0] && arguments[0].password_field !== null ? arguments[0].password_field : "");
_JS_
}

sub _get_1password_login_items {
    my ( $class, $json ) = @_;
    my @items;
    foreach my $account ( @{ $json->{accounts} } ) {
        foreach my $vault ( @{ $account->{vaults} } ) {
            foreach my $item ( @{ $vault->{items} } ) {
                if (   ( $item->{item}->{categoryUuid} eq '001' )
                    && ( $item->{item}->{overview}->{url} ) )
                {    # Login
                    push @items, $item->{item};
                }
            }
        }
    }
    return @items;
}

sub logins_from_csv {
    my ( $class, $import_handle ) = @_;
    binmode $import_handle, ':encoding(utf8)';
    my $parameters =
      $class->_csv_parameters( $class->_get_extra_parameters($import_handle) );
    $parameters->{auto_diag} = 1;
    my $csv = Text::CSV_XS->new($parameters);
    my @logins;
    my $count = 0;
    my %import_headers;

    foreach my $key ( $csv->header($import_handle) ) {
        $import_headers{$key} = $count;
        $count += 1;
    }
    my %mapping = (
        'web site'          => 'host',
        'last modified'     => 'password_changed_time',
        created             => 'creation_time',
        'login name'        => 'user',
        login_uri           => 'host',
        login_username      => 'user',
        login_password      => 'password',
        url                 => 'host',
        username            => 'user',
        password            => 'password',
        httprealm           => 'realm',
        formactionorigin    => 'origin',
        guid                => 'guid',
        timecreated         => 'creation_in_ms',
        timelastused        => 'last_used_in_ms',
        timepasswordchanged => 'password_changed_in_ms',
    );
    my %time_mapping = (
        'last modified' => 1,
        'created'       => 1,
    );
    while ( my $row = $csv->getline($import_handle) ) {
        my %parameters;
        foreach my $key ( sort { $a cmp $b } keys %import_headers ) {
            if (   ( exists $row->[ $import_headers{$key} ] )
                && ( defined $mapping{$key} ) )
            {
                $parameters{ $mapping{$key} } = $row->[ $import_headers{$key} ];
                if ( $time_mapping{$key} ) {
                    if ( $parameters{ $mapping{$key} } =~
/^(\d{4})\-(\d{2})\-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$/smx
                      )
                    {
                        my ( $year, $month, $day, $hour, $mins, $secs ) =
                          ( $1, $2, $3, $4, $5, $6 );
                        my $time =
                          Time::Local::timegm( $secs, $mins, $hour, $day,
                            $month - 1, $year );
                        $parameters{ $mapping{$key} } = $time;
                    }
                }
            }
        }
        foreach my $key (qw(host origin)) {
            if ( defined $parameters{$key} ) {
                my $uri = URI->new( $parameters{$key} )->canonical();
                if ( !$uri->has_recognized_scheme() ) {
                    my $default_scheme = 'https://';
                    warn
"$parameters{$key} does not have a recognised scheme.  Prepending '$default_scheme'\n";
                    $uri = URI->new( $default_scheme . $parameters{$key} );
                }
                $parameters{$key} = $uri->scheme() . q[://] . $uri->host();
                if ( $uri->default_port() != $uri->port() ) {
                    $parameters{$key} .= q[:] . $uri->port();
                }
            }
        }
        if (
            my $login = $class->_csv_record_is_a_login(
                $row, \%parameters, \%import_headers
            )
          )
        {
            push @logins, $login;
        }
    }
    return @logins;
}

sub _csv_record_is_a_login {
    my ( $class, $row, $parameters, $import_headers ) = @_;
    if (   ( $parameters->{host} )
        && ( $parameters->{host} eq 'http://sn' )
        && ( $import_headers->{extra} )
        && ( $row->[ $import_headers->{extra} ] )
        && ( $row->[ $import_headers->{extra} ] =~ /^NoteType:/smx ) )
    {
        warn
"Skipping non-web login for '$parameters->{user}' (probably from a LastPass export)\n";
        return;
    }
    elsif (( defined $import_headers->{'first one-time password'} )
        && ( $import_headers->{type} )
        && ( $row->[ $import_headers->{type} ] ne 'Login' )
      )    # See 001 reference for v8
    {
        warn
"Skipping $row->[ $import_headers->{type} ] record (probably from a 1Password export)\n";
        return;
    }
    elsif (( $parameters->{host} )
        && ( $parameters->{user} )
        && ( $parameters->{password} ) )
    {
        return Firefox::Marionette::Login->new( %{$parameters} );
    }
    return;
}

sub _csv_parameters {
    my ( $class, $extra ) = @_;
    return {
        binary         => 1,
        empty_is_undef => 1,
        %{$extra},
    };
}

sub _get_extra_parameters {
    my ( $class, $import_handle ) = @_;
    my @extra_parameter_sets = (
        {},                                                    # normal
        { escape_char => q[\\], allow_loose_escapes => 1 },    # KeePass
        {
            escape_char         => q[\\],
            allow_loose_escapes => 1,
            eol                 => ",$INPUT_RECORD_SEPARATOR",
        },                                                     # 1Password v7
    );
    if ( $OSNAME eq 'MSWin32' or $OSNAME eq 'cygwin' ) {
        push @extra_parameter_sets,
          {
            escape_char         => q[\\],
            allow_loose_escapes => 1,
            eol                 => ",\r\n",
          }                                                    # 1Password v7
    }
    my $extra_parameters = {};
  SET: foreach my $parameter_set (@extra_parameter_sets) {
        seek $import_handle, Fcntl::SEEK_SET(), 0
          or die "Failed to seek to start of file:$EXTENDED_OS_ERROR\n";
        my $parameters = $class->_csv_parameters($parameter_set);
        $parameters->{auto_diag} = 2;
        my $csv = Text::CSV_XS->new($parameters);
        eval {
            foreach my $key (
                $csv->header(
                    $import_handle,
                    {
                        munge_column_names => sub { defined $_ ? lc : q[] }
                    }
                )
              )
            {
            }
            while ( my $row = $csv->getline($import_handle) ) {
            }
            $extra_parameters = $parameter_set;
        } or do {
            next SET;
        };
        last SET;
    }
    seek $import_handle, Fcntl::SEEK_SET(), 0
      or die "Failed to seek to start of file:$EXTENDED_OS_ERROR\n";
    return $extra_parameters;
}

sub logins_from_xml {
    my ( $class, $import_handle ) = @_;
    my $parser = XML::Parser->new();
    my @parsed_pw_entries;
    my $current_pw_entry;
    my $key_regex_string = join q[|], qw(
      username
      url
      password
      uuid
      creationtime
      lastmodtime
      lastaccesstime
    );
    my $key_name;
    $parser->setHandlers(
        Start => sub {
            my ( $p, $element, %attributes ) = @_;
            if ( $element eq 'pwentry' ) {
                $current_pw_entry = {};
                $key_name         = undef;
            }
            elsif ( $element =~ /^($key_regex_string)$/smx ) {
                $key_name = ($1);
            }
            else {
                $key_name = undef;
            }
        },
        Char => sub {
            my ( $p, $string ) = @_;
            if ( defined $key_name ) {
                chomp $string;
                $current_pw_entry->{$key_name} .= $string;
            }
        },
        End => sub {
            my ( $p, $element ) = @_;
            $key_name = undef;
            if ( $element eq 'pwentry' ) {
                push @parsed_pw_entries, $current_pw_entry;
            }
        },
    );
    $parser->parse($import_handle);
    my @logins;
    foreach my $pw_entry (@parsed_pw_entries) {
        my $login = {};
        foreach my $key (qw(creationtime lastmodtime lastaccesstime)) {
            if (
                ( defined $pw_entry->{$key} )
                && ( $pw_entry->{$key} =~
                    /^(\d{4})\-(\d{2})\-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/smx )
              )
            {
                my ( $year, $month, $day, $hour, $mins, $secs ) =
                  ( $1, $2, $3, $4, $5, $6 );
                my $time =
                  Time::Local::timegm( $secs, $mins, $hour, $day,
                    $month - 1, $year );
                $pw_entry->{$key} = $time;
            }

        }
        my $host;
        if ( defined $pw_entry->{url} ) {
            my $url = URI::URL->new( $pw_entry->{url} );
            $host = URI::URL->new( $url->scheme() . q[://] . $url->host_port() )
              ->canonical()->as_string;
        }
        if ( ( $pw_entry->{username} ) && ($host) && ( $pw_entry->{password} ) )
        {
            push @logins,
              Firefox::Marionette::Login->new(
                host                  => $host,
                user                  => $pw_entry->{username},
                password              => $pw_entry->{password},
                guid                  => $pw_entry->{uuid},
                creation_time         => $pw_entry->{creationtime},
                password_changed_time => $pw_entry->{lastmodtime},
                last_used_time        => $pw_entry->{lastaccesstime}
              );
        }
    }
    return @logins;
}

sub logins_from_zip {
    my ( $class, $import_handle ) = @_;
    my @logins;
    my $zip = Archive::Zip->new($import_handle);
    if ( $zip->memberNamed('export.data')
        && ( $zip->memberNamed('export.attributes') ) )
    {    # 1Password v8
        my $json = JSON::decode_json( $zip->contents('export.data') );
        foreach my $item ( $class->_get_1password_login_items($json) ) {
            my ( $username, $password );
            foreach my $login_field ( @{ $item->{details}->{loginFields} } ) {
                if ( $login_field->{designation} eq 'username' ) {
                    $username = $login_field->{value};
                }
                elsif ( $login_field->{designation} eq 'password' ) {
                    $password = $login_field->{value};
                }
            }
            if ( ( defined $username ) && ( defined $password ) ) {
                push @logins,
                  Firefox::Marionette::Login->new(
                    guid                  => $item->{uuid},
                    host                  => $item->{overview}->{url},
                    user                  => $username,
                    password              => $password,
                    creation_time         => $item->{createdAt},
                    password_changed_time => $item->{updatedAt},
                  );
            }
        }
    }
    return @logins;
}

sub add_login {
    my ( $self, @parameters ) = @_;
    my $login;
    if ( scalar @parameters == 1 ) {
        $login = $parameters[0];
    }
    else {
        $login = Firefox::Marionette::Login->new(@parameters);
    }
    my $old        = $self->_context('chrome');
    my $javascript = <<"_JS_";    # xpcom/ds/nsIWritablePropertyBag2.idl
let updateMeta = function(mLoginInfo, aMetaInfo) {
  let loginMetaInfo = Components.classes["\@mozilla.org/hash-property-bag;1"].createInstance(Components.interfaces.nsIWritablePropertyBag2);
  if ("guid" in aMetaInfo && aMetaInfo.guid !== null) {
     loginMetaInfo.setPropertyAsAUTF8String("guid", aMetaInfo.guid);
  }
  if ("creation_in_ms" in aMetaInfo && aMetaInfo.creation_in_ms !== null) {
     loginMetaInfo.setPropertyAsUint64("timeCreated", aMetaInfo.creation_in_ms);
  }
  if ("last_used_in_ms" in aMetaInfo && aMetaInfo.last_used_in_ms !== null) {
     loginMetaInfo.setPropertyAsUint64("timeLastUsed", aMetaInfo.last_used_in_ms);
  }
  if ("password_changed_in_ms" in aMetaInfo && aMetaInfo.password_changed_in_ms !== null) {
    loginMetaInfo.setPropertyAsUint64("timePasswordChanged", aMetaInfo.password_changed_in_ms);
  }
  if ("times_used" in aMetaInfo && aMetaInfo.times_used !== null) {
    loginMetaInfo.setPropertyAsUint64("timesUsed", aMetaInfo.times_used);
  }
  loginManager.modifyLogin(mLoginInfo, loginMetaInfo);
};
_JS_
    if ( $self->_is_firefox_major_version_at_least( _MIN_VERSION_FOR_AWAIT() ) )
    {
        $javascript .= <<"_JS_";
if (loginManager.initializationPromise) {
  return (async function(aLoginInfo, metaInfo) {
    await loginManager.initializationPromise;
    if (loginManager.addLoginAsync) {
      let rLoginInfo = await loginManager.addLoginAsync(aLoginInfo);
      updateMeta(rLoginInfo, metaInfo);
      return rLoginInfo;
    } else {
      loginManager.addLogin(loginInfo);
      updateMeta(loginInfo, metaInfo);
      return loginInfo;
    }
  })(loginInfo, arguments[0]);
} else {
  loginManager.addLogin(loginInfo);
  updateMeta(loginInfo, arguments[0]);
  return loginInfo;
}
_JS_
    }
    else {
        $javascript .= <<"_JS_";
loginManager.addLogin(loginInfo);
updateMeta(loginInfo, arguments[0]);
return loginInfo;
_JS_
    }
    $self->script(
        $self->_compress_script(
            $self->_login_interface_preamble()
              . $self->_define_login_info_from_blessed_user(
                'loginInfo', $login
              )
              . $javascript
        ),
        args => [$login]
    );
    $self->_context($old);
    return $self;
}

sub _translate_firefox_logins {
    my ( $self, @results ) = @_;
    return map {
        Firefox::Marionette::Login->new(
            host       => $_->{hostname},
            user       => $_->{username},
            password   => $_->{password},
            user_field => $_->{usernameField} eq q[]
            ? undef
            : $_->{usernameField},
            password_field => $_->{passwordField} eq q[] ? undef
            : $_->{passwordField},
            realm  => $_->{httpRealm},
            origin => exists $_->{formActionOrigin}
            ? (
                defined $_->{formActionOrigin} && $_->{formActionOrigin} ne q[]
                ? $_->{formActionOrigin}
                : undef
              )
            : ( defined $_->{formSubmitURL}
                  && $_->{formSubmitURL} ne q[] ? $_->{formSubmitURL} : undef ),
            guid                   => $_->{guid},
            times_used             => $_->{timesUsed},
            creation_in_ms         => $_->{timeCreated},
            last_used_in_ms        => $_->{timeLastUsed},
            password_changed_in_ms => $_->{timePasswordChanged}
        )
    } @results;
}

sub logins {
    my ($self) = @_;
    my $old    = $self->_context('chrome');
    my $result = $self->script(
        $self->_compress_script(
            $self->_login_interface_preamble() . <<"_JS_") );
return loginManager.getAllLogins({});
_JS_
    $self->_context($old);
    return $self->_translate_firefox_logins( @{$result} );
}

sub _untaint_binary {
    my ( $self, $binary, $remote_path_to_binary ) = @_;
    if ( defined $remote_path_to_binary ) {
        my $quoted_binary = quotemeta $binary;
        if ( $remote_path_to_binary =~
            /^([[:alnum:]\-\/\\:()~]*$quoted_binary)$/smx )
        {
            return $1;
        }
    }
    return;
}

sub _binary_directory {
    my ($self) = @_;
    if ( exists $self->{_binary_directory} ) {
    }
    else {
        my $binary = $self->_binary();
        my $binary_directory;
        if ( $self->_ssh() ) {
            if ( $self->_remote_uname() eq 'MSWin32' ) {
                my ( $volume, $directories ) =
                  File::Spec::Win32->splitpath($binary);
                $binary_directory =
                  File::Spec::Win32->catdir( $volume, $directories );

            }
            elsif ( $self->_remote_uname() eq 'cygwin' ) {
                $binary =
                  $self->_execute_via_ssh( {}, 'cygpath', '-u', $binary );
                chomp $binary;
                my ( $volume, $directories ) =
                  File::Spec::Unix->splitpath($binary);
                $binary_directory =
                  File::Spec::Unix->catdir( $volume, $directories );
            }
            else {
                my $remote_path_to_binary = $self->_untaint_binary(
                    $binary,
                    $self->_execute_via_ssh(
                        { ignore_exit_status => 1 },
                        'which', $binary
                    )
                );
                if ( defined $remote_path_to_binary ) {
                    chomp $remote_path_to_binary;
                    if (
                        my $symlinked_path_to_binary = $self->_execute_via_ssh(
                            { ignore_exit_status => 1 },
                            'readlink',
                            '-f',
                            $remote_path_to_binary
                        )
                      )
                    {
                        my ( $volume, $directories ) =
                          File::Spec::Unix->splitpath(
                            $symlinked_path_to_binary);
                        $binary_directory =
                          File::Spec::Unix->catdir( $volume, $directories );
                    }
                    else {
                        my ( $volume, $directories ) =
                          File::Spec::Unix->splitpath($remote_path_to_binary);
                        $binary_directory =
                          File::Spec::Unix->catdir( $volume, $directories );
                    }
                }
            }
        }
        elsif ( $OSNAME eq 'cygwin' ) {
            my ( $volume, $directories ) = File::Spec::Unix->splitpath($binary);
            $binary_directory =
              File::Spec::Unix->catdir( $volume, $directories );
        }
        else {
            my ( $volume, $directories ) = File::Spec->splitpath($binary);
            $binary_directory = File::Spec->catdir( $volume, $directories );
        }
        if ( defined $binary_directory ) {
            if ( $binary_directory eq '/usr/bin' ) {
                $binary_directory = undef;
            }
        }
        $self->{_binary_directory} = $binary_directory;
    }
    return $self->{_binary_directory};
}

sub _most_recent_updates_index {
    my ($self) = @_;
    my $directory = $self->_binary_directory();
    if ( my $update_directory = $self->_updates_directory_exists($directory) ) {
        my @entries;
        foreach my $entry (
            $self->_directory_listing(
                { ignore_missing_directory => 1 },
                $update_directory, 1
            )
          )
        {
            if ( $entry =~ /^(\d{1,10})$/smx ) {
                push @entries, $1;
            }
        }
        my @sorted_entries = reverse sort { $a <=> $b } @entries;
        return shift @sorted_entries;
    }
    return;
}

sub _most_recent_updates_status_path {
    my ( $self, $index ) = @_;
    if (
        defined(
            my $most_recent_updates_index = $self->_most_recent_updates_index()
        )
      )
    {
        if ( my $updates_directory =
            $self->_updates_directory_exists( $self->_binary_directory() ) )
        {
            return $self->_catfile( $updates_directory,
                $most_recent_updates_index, 'update.status' );

        }
    }
    return;
}

sub _get_update_status {
    my ($self) = @_;
    my $updates_status_path = $self->_most_recent_updates_status_path();
    if ($updates_status_path) {
        my $updates_status_handle;
        if ( $self->_ssh() ) {
            $updates_status_handle = $self->_get_file_via_scp(
                { ignore_exit_status => 1 },
                $updates_status_path,
                'update.status file'
            );
        }
        else {
            $updates_status_handle =
              FileHandle->new( $updates_status_path, Fcntl::O_RDONLY() );
        }
        if ($updates_status_handle) {
            my $status = $self->_read_and_close_handle( $updates_status_handle,
                $updates_status_path );
            chomp $status;
            return $status;
        }
        elsif ( ( $self->_ssh() ) || ( $OS_ERROR == POSIX::ENOENT() ) ) {
        }
        else {
            Firefox::Marionette::Exception->throw(
"Failed to open '$updates_status_path' for reading:$EXTENDED_OS_ERROR"
            );
        }
    }
    return;
}

sub _wait_for_any_background_update_status {
    my ($self) = @_;
    my $update_status = $self->_get_update_status();
    while ( ( defined $update_status ) && ( $update_status eq 'applying' ) ) {
        sleep 1;
        $update_status = $self->_get_update_status();
    }
    return;
}

sub _displays {
    my ($self) = @_;

# Retrieved and translated from https://en.wikipedia.org/wiki/List_of_common_resolutions
    my $displays = <<"_DISPLAYS_";
0.26K1	Microvision	16	16	1:1	1:1	1:1	256
0.46K1	Timex Datalink USB[1][2]	42	11	42:11	1:1	5:9	462
1.02K1	PocketStation	32	32	1:1	1:1	1:1	1,024
1.2K3	Etch A Sketch Animator	40	30	4:3	4:3	1:1	1,200
1.34K1	Epson RC-20[3]	42	32	42:32	1:1	0.762	1,344
1.54K2	GameKing I (GM-218), VMU	48	32	3:2	3:2	1:1	1,536
2.4K2	Etch A Sketch Animator 2000	60	40	3:2	3:2	1:1	2,400
4.03K7:4	Nokia 3210 and many other early Nokia Phones	84	48	7:4	2:1	1.143	4,032
4.1K1	Hartung Game Master	64	64	1:1	1:1	1:1	4,096
4.61K1	Field Technology CxMP smart watch[2]	72	64	72:64	1:1	0.889	4,608
4.61K1	Montblanc e-Strap[4]	128	36	128:36	1:1	0.281	4,608
4.8K1	Epoch Game Pocket Computer	75	64	75:64	1:1	1:1.171875	4,800
0.01M3.75	Entex Adventure Vision	150	40	150:40	3.75	1:1	6,000
0.01M2	First graphing calculators: Casio fx-7000G, TI-81	96	64	3:2	3:2	1:1	6,144
0.01M2	Pok\x{E9}mon Mini	96	64	3:2	3:2	1:1	6,144
0.01M2	TRS-80	128	48	128:48	3:2	0.563	6,144
0.01M2	Early Nokia colour screen phones	96	65	96:65	3:2	1.016	6,240
0.01MA	Ruputer	102	64	102:64	8:5	1.004	6,528
0.01M4	Sony Ericsson T68i, T300, T310 and other early colour screen phones	101	80	101:80	5:4	0.99	8,080
0.01M1	MetaWatch Strata & Frame watches	96	96	1:1	1:1	1:1	9,216
0.02M3.75	Atari Portfolio, TRS-80 Model 100	240	64	240:64	3.75	1:1	15,360
0.02MA	Atari Lynx	160	102	160:102	8:5	1.02	16,320
0.02M1	Sony SmartWatch, Sifteo cubes, early color screen phones (square display)	128	128	1:1	1:1	1:1	16,384
QQVGA	Quarter Quarter VGA	160	120	4:3	4:3	1:1	19,200
0.02M1.111	Nintendo Game Boy (GB), Game Boy Color (GBC); Sega Game Gear (GG)	160	144	160:144	10:9	1:1	23,040
0.02M0.857	Pebble E-Paper Watch	144	168	144:168	6:7	1:1	24,192
0.02M1.053	Neo Geo Pocket Color	160	152	160:152	20:19	1:1	24,320
0.03M1	Palm LoRes	160	160	1:1	1:1	1:1	25,600
0.03M3	Apple II HiRes (6 color) and Apple IIe Double HiRes (16 color), grouping subpixels	140	192	140:192	4:3	1.828	26,880
0.03M3	VIC-II multicolor, IBM PCjr 16-color, Amstrad CPC 16-color	160	200	160:200	4:3	5:3	32,000
0.03M9	WonderSwan	224	144	14:9	14:9	1:1	32,256
0.04M13:11	Nokia Series 60 smartphones (Nokia 7650, plus First and Second Edition models only)	208	176	13:11	13:11	1:1	36,608
HQVGA	Half QVGA: Nintendo Game Boy Advance	240	160	3:2	3:2	1:1	38,400
0.04M4	Older Java MIDP devices like Sony Ericsson K600	220	176	5:4	5:4	1:1	38,720
0.04M3	Acorn BBC 20 column modes	160	256	160:256	4:3	2.133	40,960
0.04M1	Nokia 5500 Sport, Nokia 6230i, Nokia 8800	208	208	1:1	1:1	1:1	43,264
0.05M3	TMS9918 modes 1 (e.g. TI-99/4A) and 2, ZX Spectrum, MSX, Sega Master System, Nintendo DS (each screen)	256	192	4:3	4:3	1:1	49,152
0.05M3	Apple II HiRes (1 bit per pixel)	280	192	280:192	4:3	0.914	53,760
0.05M3	MSX2	256	212	256:212	4:3	1.104	54,272
0.06M1	Samsung Gear Fit	432	128	432:128	1:1	0.296	55,296
0.06M3	Nintendo Entertainment System, Super Nintendo Entertainment System, Sega Mega Drive	256	224	256:224	4:3	7:6	57,344
0.06M1	Apple iPod Nano 6G	240	240	1:1	1:1	1:1	57,600
0.06M3	Sony PlayStation (e.g. Rockman Complete Works)	256	240	256:240	4:3	5:4	61,440
0.06M6	Atari 400/800 PAL	320	192	5:3	5:3	1:1	61,440
0.06M5:3	Atari 400/800 NTSC	320	192	5:3	50:35	6:7	61,440
Color Graphics Adapter (CGA)	CGA 4-color, ATM 16 color, Atari ST 16 color, Commodore 64 VIC-II Hires, Amiga OCS NTSC Lowres, Apple IIGS LoRes, MCGA, Amstrad CPC 4-color	320	200	8:5	4:3	0.833	64,000
0.07M1	Elektronika BK	256	256	1:1	1:1	1:1	65,536
0.07M3	Sinclair QL	256	256	1:1	4:3	4:3	65,536
0.07M2	UIQ 2.x based smartphones	320	208	320:208	3:2	0.975	66,560
0.07M2	Sega Mega Drive, Sega Nomad, Neo Geo AES	320	224	10:7	3:2	1.05	71,680
QVGA	Quarter VGA: Apple iPod Nano 3G, Sony PlayStation, Nintendo 64, Nintendo 3DS (lower screen)	320	240	4:3	4:3	1:1	76,800
0.08M4	Acorn BBC 40 column modes, Amiga OCS PAL Lowres	320	256	5:4	5:4	1:1	81,920
0.09M3	Capcom CP System (CPS, CPS2, CPS3) arcade system boards	384	224	384:224	4:3	0.778	86,016
0.09M3	Sony PlayStation (e.g. X-Men vs. Street Fighter)	368	240	368:240	4:3	0.869	88,320
0.09M9	Apple iPod Nano 5G	376	240	376:240	14:9	0.993	90,240
0.09M0.8	Apple Watch 38mm	272	340	272:340	4:5	1:1	92,480
WQVGA	Wide QVGA: Common on Windows Mobile 6 handsets	400	240	5:3	5:3	1:1	96,000
0.1M3	Timex Sinclair 2068, Timex Computer 2048	512	192	512:192	4:3	0.5	98,304
0.1M3	IGS PolyGame Master arcade system board	448	224	2:1	4:3	0.667	100,352
0.1M1	Palm (PDA) HiRes, Samsung Galaxy Gear	320	320	1:1	1:1	1:1	102,400
WQVGA	Wide QVGA: Apple iPod Nano 7G	432	240	9:5	9:5	1:1	103,680
0.11M3	Apple IIe Double Hires (1 bit per pixel)[5]	560	192	560:192	4:3	0.457	107,520
0.11M2	TurboExpress	400	270	400:270	3:2	1.013	108,000
0.11M3	MSX2	512	212	512:212	4:3	0.552	108,544
0.11M3	Common Intermediate Format	384	288	4:3	4:3	1:1	110,592
WQVGA*	Variant used commonly for portable DVD players, digital photo frames, GPS receivers and devices such as the Kenwood DNX-5120 and Glospace SGK-70; often marketed as "16:9"	480	234	480:234	16:9	0.866	112,320
qSVGA	Quarter SVGA: Selectable in some PC shooters	400	300	4:3	4:3	1:1	120,000
0.12M3	Teletext and Viewdata 40x25 character screens (PAL non-interlaced)	480	250	480:250	4:3	0.694	120,000
0.12M0.8	Apple Watch 42mm	312	390	312:390	4:5	1:1	121,680
0.12M3	Sony PlayStation (e.g. Tekken and Tekken 2)	512	240	512:240	4:3	0.625	122,880
0.13M3	Amiga OCS NTSC Lowres interlaced	320	400	320:400	4:3	5:3	128,000
Color Graphics Adapter (CGA)	Atari ST 4 color, ATM, CGA mono, Amiga OCS NTSC Hires, Apple IIGS HiRes, Nokia Series 80 smartphones, Amstrad CPC 2-color	640	200	640:200	4:3	0.417	128,000
0.13M9	Sony PlayStation Portable, Zune HD, Neo Geo X	480	272	480:272	16:9	1.007	130,560
0.13M2:1	Elektronika BK, Polyplay	512	256	2:1	2:1	1:1	131,072
0.13M3	Sinclair QL	512	256	2:1	4:3	0.667	131,072
0.15M13:11	Nokia Series 60 smartphones (E60, E70, N80, N90)	416	352	13:11	13:11	1:1	146,432
HVGA	Palm Tungsten T3, Apple iPhone, HTC Dream, Palm (PDA) HiRES+	480	320	3:2	3:2	1:1	153,600
HVGA	Handheld PC	640	240	640:240	8:3	1:1	153,600
0.15M3	Sony PlayStation	640	240	640:240	4:3	0.5	153,600
0.16M3	Acorn BBC 80 column modes, Amiga OCS PAL Hires	640	256	640:256	4:3	0.533	163,840
0.18M2	Black & white Macintosh (9")	512	342	512:342	3:2	1.002	175,104
0.18M3	Sony PlayStation (e.g. Tekken 3) (interlaced)	368	480	368:480	4:3	1.739	176,640
0.19M3	Sega Model 1 (e.g. Virtua Fighter) and Model 2 (e.g. Daytona USA) arcade system boards	496	384	496:384	4:3	1.032	190,464
0.19M6	Nintendo 3DS (upper screen in 3D mode: 2x 400 x 240, one for each eye)	800	240	800:240	5:3	0.5	192,000
0.2M3	Macintosh LC (12")/Color Classic (also selectable in many PC shooters)	512	384	4:3	4:3	1:1	196,608
0.2M2:1	Nokia Series 90 smartphones (7700, 7710)	640	320	2:1	2:1	1:1	204,800
EGA	Enhanced Graphics Adapter	640	350	640:350	4:3	0.729	224,000
0.23M9	nHD, used by Nokia 5800, Nokia 5530, Nokia X6, Nokia N97, Nokia N8[6]	640	360	16:9	16:9	1:1	230,400
0.24M3	Teletext and Viewdata 40x25 character screens (PAL interlaced)	480	500	480:500	4:3	1.399	240,000
0.25M3	Namco System 12 arcade system board (e.g. Soulcalibur, Tekken 3, Tekken Tag Tournament) (interlaced)	512	480	512:480	4:3	5:4	245,760
0.25M3	HGC	720	348	720:348	4:3	0.644	250,560
0.25M3	MDA	720	350	720:350	4:3	0.648	252,000
0.26M3	Atari ST mono, Amiga OCS NTSC Hires interlaced	640	400	8:5	4:3	0.833	256,000
0.26M3	Apple Lisa	720	364	720:364	4:3	0.674	262,080
0.28M2.273	Nokia E90 Communicator	800	352	800:352	25:11	1:1	281,600
0.29M4	Some older monitors	600	480	5:4	5:4	1:1	288,000
VGA	Video Graphics Array:MCGA (in monochome), Sun-1 color, Sony PlayStation (e.g. Tobal No.1 and Ehrgeiz), Nintendo 64 (e.g. various Expansion Pak enhanced games), 6th Generation Consoles, Nintendo Wii	640	480	4:3	4:3	1:1	307,200
0.33M3	Amiga OCS PAL Hires interlaced	640	512	5:4	4:3	1.066	327,680
WVGA	Wide VGA	768	480	8:5	8:5	1:1	368,640
WGA	Wide VGA: List of mobile phones with WVGA display	800	480	5:3	5:3	1:1	384,000
W-PAL	Wide PAL	848	480	848:480	16:9	1.006	407,040
FWVGA	List of mobile phones with FWVGA display	854	480	854:480	16:9	0.999	409,920
SVGA	Super VGA	800	600	4:3	4:3	1:1	480,000
qHD	Quarter FHD: AACS ICT, HRHD, Motorola Atrix 4G, Sony XEL-1[7][unreliable source?]	960	540	16:9	16:9	1:1	518,400
0.52M3	Apple Macintosh Half Megapixel[8]	832	624	4:3	4:3	1:1	519,168
0.52M9	PlayStation Vita (PSV)	960	544	960:544	16:9	1.007	522,240
0.59M9	PAL 16:9	1024	576	16:9	16:9	1:1	589,824
DVGA	Double VGA: Apple iPhone 4S,[9][unreliable source?][10] 4th Generation iPod Touch[11]	960	640	3:2	3:2	1:1	614,400
WSVGA	Wide SVGA: 10" netbooks	1024	600	1024:600	16:9	1.041	614,400
0.66MA	Close to WSVGA	1024	640	8:5	8:5	1:1	655,360
0.69M3	Panasonic DVCPRO100 for 50/60 Hz over 720p - SMPTE Resolution	960	720	4:3	4:3	1:1	691,200
0.73M9	Apple iPhone 5, iPhone 5S, iPhone 5C, iPhone SE (1st)	1136	640	1136:640	16:9	1.001	727,040
0.73M9	Occasional Chromebook resolution with 96 DPI; see HP Chromebook 14A G5.	1138	640	16:9	16:9	0.999	728,320
XGA	Extended Graphics Array:Common on 14"/15" TFTs and the Apple iPad	1024	768	4:3	4:3	1:1	786,432
0.82M3	Sun-1 monochrome	1024	800	32:25	4:3	1.041	819,200
0.83MA	Supported by some GPUs, monitors, and games	1152	720	8:5	8:5	1:1	829,440
0.88M2	Apple PowerBook G4 (original Titanium version)	1152	768	3:2	3:2	1:1	884,736
WXGA-H	Wide XGA:Minimum, 720p HDTV	1280	720	16:9	16:9	1:1	921,600
0.93M3	NeXT MegaPixel Display	1120	832	1120:832	4:3	0.99	931,840
WXGA	Wide XGA:Average, BrightView	1280	768	5:3	5:3	1:1	983,040
XGA+	Apple XGA[note 2]	1152	864	4:3	4:3	1:1	995,328
1M9	Apple iPhone 6, iPhone 6S, iPhone 7, iPhone 8, iPhone SE (2nd)	1334	750	1334:750	16:9	0.999	1,000,500
WXGA	Wide XGA:Maximum	1280	800	8:5	8:5	1:1	1,024,000
1.04M32:25	Sun-2 Prime Monochrome or Color Video, also common in Sun-3 and Sun-4 workstations	1152	900	32:25	32:25	1:1	1,036,800
1.05M1:1	Network Computing Devices	1024	1024	1:1	1:1	1:1	1,048,576
1.05M9	Standardized HDTV 720p/1080i displays or "HD ready", used in most cheaper notebooks	1366	768	1366:768	16:9	0.999	1,049,088
1.09M2	Apple PowerBook G4	1280	854	1280:854	3:2	1.001	1,093,120
SXGA-	Super XGA "Minus"	1280	960	4:3	4:3	1:1	1,228,800
1.23M2.083	Sony VAIO P series	1600	768	1600:768	25:12	1:1	1,228,800
1.3M0.9	HTC Vive (per eye)	1080	1200	1080:1200	9:10	1:1	1,296,000
WSXGA	Wide SXGA	1440	900	8:5	8:5	1:1	1,296,000
WXGA+	Wide XGA+	1440	900	8:5	8:5	1:1	1,296,000
SXGA	Super XGA	1280	1024	5:4	5:4	1:1	1,310,720
1.39M2	Apple PowerBook G4	1440	960	3:2	3:2	1:1	1,382,400
HD+	900p	1600	900	16:9	16:9	1:1	1,440,000
SXGA+	Super XGA Plus, Lenovo Thinkpad X61 Tablet	1400	1050	4:3	4:3	1:1	1,470,000
1.47M5	Similar to A4 paper format (~123 dpi for A4 size)	1440	1024	1440:1024	7:5	0.996	1,474,560
1.56M3	HDV 1080i	1440	1080	4:3	4:3	1:1	1,555,200
1.64M10	SGI 1600SW	1600	1024	25:16	25:16	1:1	1,638,400
WSXGA+	Wide SXGA+	1680	1050	8:5	8:5	1:1	1,764,000
1.78M9	Available in some monitors	1776	1000	1776:1000	16:9	1.001	1,776,000
UXGA	Ultra XGA:Lenovo Thinkpad T60	1600	1200	4:3	4:3	1:1	1,920,000
2.05M4	Sun3 Hi-res monochrome	1600	1280	5:4	5:4	1:1	2,048,000
FHD	Full HD:1080 HDTV (1080i, 1080p)	1920	1080	16:9	16:9	1:1	2,073,600
2.07M1	Windows Mixed Reality headsets (per eye)	1440	1440	1:1	1:1	1:1	2,073,600
DCI 2K	DCI 2K	2048	1080	2048:1080	1.90:1	1.002	2,211,840
WUXGA	Wide UXGA	1920	1200	8:5	8:5	1:1	2,304,000
QWXGA	Quad WXGA, 2K	2048	1152	16:9	16:9	1:1	2,359,296
2.41M3	Supported by some GPUs, monitors, and games	1792	1344	4:3	4:3	1:1	2,408,448
FHD+	Full HD Plus:Microsoft Surface 3	1920	1280	3:2	3:2	1:1	2,457,600
2.46M2.10:1	Samsung Galaxy S10e, Xiaomi Mi A2 Lite, Huawei P20 Lite	2280	1080	2.10:1	2.10:1	1:1	2,462,400
2.53M2.167	Samsung Galaxy A8s, Xiaomi Redmi Note 7, Honor Play	2340	1080	19.5:9	19.5:9	1:1	2,527,200
2.58M3	Supported by some GPUs, monitors, and games	1856	1392	4:3	4:3	1:1	2,583,552
2.59M09?	Samsung Galaxy A70, Samsung Galaxy S21/+, Xiaomi Redmi Note 9S, default for many 3200x1440 phones[12]	2400	1080	20:9	20:9	1:1	2,592,000
2.59M4	Supported by some GPUs, monitors, and games	1800	1440	5:4	5:4	1:1	2,592,000
CWSXGA	NEC CRV43,[13] Ostendo CRVD,[14] Alienware Curved Display[15][16]	2880	900	2880:900	16:5	1:1	2,592,000
2.59M9	HTC Vive, Oculus Rift (both eyes)	2160	1200	9:5	9:5	1:1	2,592,000
2.62MA	Supported by some GPUs, monitors, and games	2048	1280	8:5	8:5	1:1	2,621,440
TXGA	Tesselar XGA	1920	1400	1920:1400	7:5	1.021	2,688,000
2.72M1A	Motorola One Vision, Motorola One Action and Sony Xperia 10 IV	2520	1080	21:9	21:9	1:1	2,721,600
2.74M2.165	Apple iPhone X, iPhone XS and iPhone 11 Pro	2436	1125	2436:1125	2.165	1:1	2,740,500
2.74M1AD	Avielo Optix SuperWide 235 projector[17]	2538	1080	2.35:1	2.35:1	1.017	2,741,040
2.76M3	Supported by some GPUs, monitors, and games	1920	1440	4:3	4:3	1:1	2,764,800
UW-FHD	UltraWide FHD:Cinema TV from Philips and Vizio, Dell UltraSharp U2913WM, ASUS MX299Q, NEC EA294WMi, Philips 298X4QJAB, LG 29EA93, AOC Q2963PM	2560	1080	21:9	21:9	1:1	2,764,800
3.11M2	Microsoft Surface Pro 3	2160	1440	3:2	3:2	1:1	3,110,400
QXGA	Quad XGA:iPad (3rd Generation), iPad Mini (2nd Generation)	2048	1536	4:3	4:3	1:1	3,145,728
3.32MA	Maximum resolution of the Sony GDM-FW900, Hewlett Packard A7217A and the Retina Display MacBook	2304	1440	8:5	8:5	1:1	3,317,760
3.39MA	Surface Laptop	2256	1504	3:2	8:5	1.067	3,393,024
WQHD	Wide Quad HD:Dell UltraSharp U2711, Dell XPS One 27, Apple iMac	2560	1440	16:9	16:9	1:1	3,686,400
3.98M3	Supported by some displays and graphics cards[18][unreliable source?][19]	2304	1728	4:3	4:3	1:1	3,981,312
WQXGA	Wide QXGA:Apple Cinema HD 30, Apple 13" MacBook Pro Retina Display, Dell Ultrasharp U3011, Dell 3007WFP, Dell 3008WFP, Gateway XHD3000, Samsung 305T, HP LP3065, HP ZR30W, Nexus 10	2560	1600	8:5	8:5	1:1	4,096,000
4.15M2:1	LG G6, LG V30, Pixel 2 XL, HTC U11+, Windows Mixed Reality headsets (both eyes)	2880	1440	2:1	2:1	1:1	4,147,200
Infinity Display	Samsung Galaxy S8, S8+, S9, S9+, Note 8	2960	1440	18.5:9	18.5:9	1:1	4,262,400
4.35M2	Chromebook Pixel	2560	1700	3:2	3:2	1:1	4,352,000
4.61M1.422	Pixel C	2560	1800	64:45	64:45	1:1	4,608,000
4.67MA	Lenovo Thinkpad W541	2880	1620	16:9	8:5	0.9	4,665,600
4.92M3	Max. CRT resolution, supported by the Viewsonic P225f and some graphics cards	2560	1920	4:3	4:3	1:1	4,915,200
Ultra-Wide QHD	LG, Samsung, Acer, HP and Dell UltraWide monitors	3440	1440	21:9	21:9	1:1	4,953,600
4.99M2	Microsoft Surface Pro 4	2736	1824	3:2	3:2	1:1	4,990,464
5.18MA	Apple 15" MacBook Pro Retina Display	2880	1800	8:5	8:5	1:1	5,184,000
QSXGA	Quad SXGA	2560	2048	5:4	5:4	1:1	5,242,880
5.6M3	iPad Pro 12.9"	2732	2048	4:3	4:3	0.999	5,595,136
WQXGA+	Wide QXGA+:HP Envy TouchSmart 14, Fujitsu Lifebook UH90/L, Lenovo Yoga 2 Pro	3200	1800	16:9	16:9	1:1	5,760,000
QSXGA+	Quad SXGA+	2800	2100	4:3	4:3	1:1	5,880,000
5.9MA	Apple 16" MacBook Pro Retina Display	3072	1920	8:5	8:5	1:1	5,898,240
3K	Microsoft Surface Book, Huawei MateBook X Pro[20]	3000	2000	3:2	3:2	1:1	6,000,000
UW4K	Ultra-Wide 4K	3840	1600	2.35:1	21:9	0.988	6,144,000
WQSXGA	Wide QSXGA	3200	2048	25:16	25:16	1:1	6,553,600
7M2	Microsoft Surface Book 2 15"	3240	2160	3:2	3:2	1:1	6,998,400
DWQHD	Dual Wide Quad HD: Philips 499P9H, Dell U4919DW, Samsung C49RG94SSU	5120	1440	32:9	32:9	1:1	7,372,800
QUXGA	Quad UXGA	3200	2400	4:3	4:3	1:1	7,680,000
4K UHD-1	4K Ultra HD 1:2160p, 4000-lines UHDTV (4K UHD)	3840	2160	16:9	16:9	1:1	8,294,400
DCI 4K	DCI 4K	4096	2160	1.90:1	1.90:1	1.002	8,847,360
WQUXGA	Wide QUXGA:IBM T221	3840	2400	8:5	8:5	1:1	9,216,000
9.44M9	LG Ultrafine 21.5, Apple 21.5" iMac 4K Retina Display	4096	2304	16:9	16:9	1:1	9,437,184
UW5K (WUHD)	Ultra-Wide 5K:21:9 aspect ratio TVs	5120	2160	21:9	21:9	1:1	11,059,200
11.29M9	Apple 24" iMac 4.5K Retina Display	4480	2520	16:9	16:9	1:1	11,289,600
HXGA	Hex XGA	4096	3072	4:3	4:3	1:1	12,582,912
13.5M2	Surface Studio	4500	3000	3:2	3:2	1:1	13,500,000
5K	Dell UP2715K, LG Ultrafine 27, Apple 27" iMac 5K Retina Display	5120	2880	16:9	16:9	1:1	14,745,600
WHXGA	Wide HXGA	5120	3200	8:5	8:5	1:1	16,384,000
HSXGA	Hex SXGA	5120	4096	5:4	5:4	1:1	20,971,520
6K	Apple 32" Pro Display XDR[21] 6K Retina Display	6016	3384	16:9	16:9	1:1	20,358,144
WHSXGA	Wide HSXGA	6400	4096	25:16	25:16	1:1	26,214,400
HUXGA	Hex UXGA	6400	4800	4:3	4:3	1:1	30,720,000
-		6480	3240	2:1	2:1	1:1	20,995,200
8K UHD-2	8K Ultra HD 2:4320p, 8000-lines UHDTV (8K UHD)	7680	4320	16:9	16:9	1:1	33,177,600
WHUXGA	Wide HUXGA	7680	4800	8:5	8:5	1:1	36,864,000
8K Full Format	DCI 8K	8192	4320	1.90:1	1.90:1	1.002	35,389,440
-		8192	4608	16:9	16:9	1:1	37,748,736
UW10K	Ultra-Wide 10K	10240	4320	21:9	21:9	1:1	44,236,800
8K Fulldome	8K Fulldome	8192	8192	1:1	1:1	1:1	67,108,864
16K	16K	15360	8640	16:9	16:9	1:1	132,710,400
_DISPLAYS_
    my @displays;
    my $csv = Text::CSV_XS->new(
        {
            auto_diag          => 2,
            sep_char           => "\t",
            binary             => 1,
            allow_loose_quotes => 1
        }
    );
    foreach my $line ( split /\r?\n/smx, $displays ) {
        $csv->parse($line);
        my @fields = $csv->fields();
        my $index  = 0;
        push @displays,
          Firefox::Marionette::Display->new(
            designation => $fields[ $index++ ],
            usage       => $fields[ $index++ ],
            width       => $fields[ $index++ ],
            height      => $fields[ $index++ ],
            sar         => $fields[ $index++ ],
            dar         => $fields[ $index++ ],
            par         => $fields[ $index++ ]
          );
    }
    @displays = sort { $a->total() < $b->total() } @displays;
    return @displays;
}

my $cached_per_display_key_name = '_cached_per_display';

sub _check_for_min_max_sizes {
    my ($self) = @_;
    if ( $self->{$cached_per_display_key_name} ) {
    }
    else {
        my ( $current_width, $current_height ) = @{
            $self->script(
                $self->_compress_script(
                    q[return [window.outerWidth, window.outerHeight]])
            )
        };
        $self->maximise();
        my ( $maximum_width, $maximum_height ) = @{
            $self->script(
                $self->_compress_script(
                    q[return [window.outerWidth, window.outerHeight]])
            )
        };
        if ( $current_width > $maximum_width ) {
            $current_width = $maximum_width;
        }
        if ( $current_height > $maximum_height ) {
            $current_height = $maximum_height;
        }
        $self->_resize( 0, 0 );    # getting minimum size
        my ( $minimum_width, $minimum_height ) = @{
            $self->script(
                $self->_compress_script(
                    q[return [window.outerWidth, window.outerHeight]])
            )
        };
        $self->{$cached_per_display_key_name} = {
            maximum => { width => $maximum_width, height => $maximum_height },
            minimum => { width => $minimum_width, height => $minimum_height }
        };
        if (   ( $current_width == $minimum_width )
            && ( $current_height == $minimum_height ) )
        {
        }
        else {
            $self->resize( $current_width, $current_height );
        }
    }
    return;
}

sub displays {
    my ( $self, $filter ) = @_;
    my $csv = Text::CSV_XS->new(
        {
            auto_diag          => 2,
            sep_char           => "\t",
            binary             => 1,
            allow_loose_quotes => 1
        }
    );
    my @displays;
    foreach my $display ( $self->_displays() ) {
        if ( ( defined $filter ) && ( $display->usage() !~ /$filter/smx ) ) {
            next;
        }
        push @displays, $display;
    }
    return @displays;
}

sub _resize {
    my ( $self, $width, $height ) = @_;
    my $old = $self->_context('chrome');

    # https://developer.mozilla.org/en-US/docs/Web/API/Window/resizeTo
    # https://developer.mozilla.org/en-US/docs/Web/API/Window/resize_event
    my $result = $self->script(
        $self->_compress_script(
            <<"_JS_"
let expectedWidth = arguments[0];
let expectedHeight = arguments[1];
if ((window.outerWidth == expectedWidth) && (window.outerHeight == expectedHeight)) {
  return true;
} else if ((window.screen.availWidth < expectedWidth) || (window.screen.availHeight < expectedHeight)) {
  return false;
} else {
  let windowResized = function(argumentWidth, argumentHeight) {
    return new Promise((resolve) => {
      let waitForResize = function(event) {
        window.removeEventListener('resize', waitForResize);
        if ((window.outerWidth == argumentWidth) && (window.outerHeight == argumentHeight)) {
          resolve(true);
        } else {
          resolve(false);
        }
      };
      window.addEventListener('resize', waitForResize);
      window.resizeTo(expectedWidth, expectedHeight);
    })
  };
  let result = (async function() {
      let awaitResult = await windowResized(expectedWidth, expectedHeight);
      return awaitResult;
  })();
  return result;
}
_JS_
        ),
        args => [ $width, $height ]
    );
    $self->_context($old);
    return $result;
}

sub resize {
    my ( $self, $width, $height ) = @_;
    $self->_check_for_min_max_sizes();
    my $return_value;
    if ( $self->{$cached_per_display_key_name}->{maximum}->{height} < $height )
    {
        $return_value = 0;
    }
    if ( $self->{$cached_per_display_key_name}->{maximum}->{width} < $width ) {
        $return_value = 0;
    }
    if ( $self->{$cached_per_display_key_name}->{minimum}->{height} > $height )
    {
        $return_value = 0;
    }
    if ( $self->{$cached_per_display_key_name}->{minimum}->{width} > $width ) {
        $return_value = 0;
    }
    if ( defined $return_value ) {
        return $return_value;
    }
    else {
        return $self->_resize( $width, $height ) ? $self : undef;
    }
}

sub percentage_visible {
    my ( $self, $element ) = @_;
    my $percentage = $self->script(
        $self->_compress_script(
            <<"_JS_"
let selectedElement = arguments[0];
let position = selectedElement.getBoundingClientRect();
let computedStyle = window.getComputedStyle(selectedElement);
let totalVisible = 0;
let totalPixels = 0;
let visibleAtPoint = function(x,y) {
  let elementsAtPoint = document.elementsFromPoint(x, y);
  let visiblePoint = false;
  let foundAnotherVisibleElement = false;
  for (let i = 0; i < elementsAtPoint.length; i++) {
    let computedStyle = window.getComputedStyle(elementsAtPoint[i]);
    if ((computedStyle.visibility === 'hidden') || (computedStyle.visibility === 'collapse') || (computedStyle.display === 'none')) {
      if (elementsAtPoint[i].isEqualNode(selectedElement)) {
        visiblePoint = false;
        break;
      }
    } else {
      if (elementsAtPoint[i].isEqualNode(selectedElement)) {
        if (foundAnotherVisibleElement) {
          visiblePoint = false;
        } else {
          visiblePoint = true;
          break;
        }
      } else {
        foundAnotherVisibleElement = true;
      }
    }
  }
  return visiblePoint;
};
for (let x = parseInt(position.left); x < parseInt(position.left + position.width); x++) {
  for (let y = parseInt(position.top); y < parseInt(position.top + position.height); y++) {
    let result = visibleAtPoint(x,y);
    if (result === false) {
      totalPixels = totalPixels + 1;
    } else if (result == true) {
      totalVisible = totalVisible + 1;
      totalPixels = totalPixels + 1;
    }
  }
}
if (totalPixels > 0) {
	return (totalVisible / totalPixels) * 100;
} else {
	return 0;
}
_JS_
        ),
        args => [$element]
    );
    return $percentage;
}

sub restart {
    my ($self)       = @_;
    my $capabilities = $self->capabilities();
    my $timeouts     = $self->timeouts();
    if ( $self->_session_id() ) {
        $self->_quit_over_marionette();
        delete $self->{session_id};
    }
    else {
        $self->_terminate_marionette_process();
    }
    $self->_wait_for_any_background_update_status();
    foreach my $key (
        qw(marionette_protocol application_type _firefox_pid last_message_id _child_error)
      )
    {
        delete $self->{$key};
    }
    if ( my $ssh = $self->_ssh() ) {
        delete $ssh->{ssh_local_tcp_socket};
    }
    delete $self->{_cached_per_instance};
    $self->_reset_marionette_port();
    $self->_get_version();
    my @arguments =
      $self->_setup_arguments( %{ $self->{_restart_parameters} } );
    $self->_launch(@arguments);
    my $socket = $self->_setup_local_connection_to_firefox(@arguments);
    my $session_id;
    ( $session_id, $capabilities ) =
      $self->_initial_socket_setup( $socket, $capabilities );
    $self->_check_protocol_version_and_pid( $session_id, $capabilities );
    $self->_post_launch_checks_and_setup($timeouts);
    return $self;
}

sub _reset_marionette_port {
    my ($self) = @_;
    my $handle;
    if ( $self->_ssh() ) {
        $handle =
          $self->_get_file_via_scp( {}, $self->{profile_path}, 'profile path' );
    }
    else {
        $handle = FileHandle->new( $self->{profile_path}, Fcntl::O_RDONLY() )
          or Firefox::Marionette::Exception->throw(
"Failed to open '$self->{profile_path}' for reading:$EXTENDED_OS_ERROR"
          );
    }
    my $profile = Firefox::Marionette::Profile->parse_by_handle($handle);
    close $handle
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$self->{profile_path}':$EXTENDED_OS_ERROR");
    if ( $self->_is_auto_listen_okay() ) {
        $profile->set_value( 'marionette.port',
            Firefox::Marionette::Profile::ANY_PORT() );
    }
    else {
        my $port = $self->_get_empty_port();
        $profile->set_value( 'marionette.defaultPrefs.port', $port );
        $profile->set_value( 'marionette.port',              $port );
    }
    if ( $self->_ssh() ) {
        $self->_save_profile_via_ssh($profile);
    }
    else {
        $profile->save( $self->{profile_path} );
    }
    return;
}

sub update {
    my ( $self, $update_timeout ) = @_;
    my $timeouts        = $self->timeouts();
    my $script_timeout  = $timeouts->script();
    my $update_timeouts = Firefox::Marionette::Timeouts->new(
        script => ( $update_timeout || _DEFAULT_UPDATE_TIMEOUT() ) *
          _MILLISECONDS_IN_ONE_SECOND(),
        implicit  => $timeouts->implicit(),
        page_load => $timeouts->page_load()
    );
    $self->timeouts($update_timeouts);
    my $old = $self->_context('chrome');

    # toolkit/mozapps/update/nsIUpdateService.idl
    my $update_parameters = $self->script(
        $self->_compress_script(
            $self->_prefs_interface_preamble() . <<'_JS_') );
let disabledForTesting = branch.getBoolPref("app.update.disabledForTesting");
branch.setBoolPref("app.update.disabledForTesting", false);
let updateManager = new Promise((resolve, reject) => {
  var updateStatus = {};
  if ("@mozilla.org/updates/update-manager;1" in Components.classes) {
    let PREF_APP_UPDATE_CANCELATIONS_OSX = "app.update.cancelations.osx";
    let PREF_APP_UPDATE_ELEVATE_NEVER = "app.update.elevate.never";
    if (Services.prefs.prefHasUserValue(PREF_APP_UPDATE_CANCELATIONS_OSX)) {
      Services.prefs.clearUserPref(PREF_APP_UPDATE_CANCELATIONS_OSX);
    }
    if (Services.prefs.prefHasUserValue(PREF_APP_UPDATE_ELEVATE_NEVER)) {
      Services.prefs.clearUserPref(PREF_APP_UPDATE_ELEVATE_NEVER);
    }
    let updateService = Components.classes["@mozilla.org/updates/update-service;1"].getService(Components.interfaces.nsIApplicationUpdateService);
    let latestUpdate = null;
    if (!updateService.canCheckForUpdates) {
      updateStatus["updateStatusCode"] = 'CANNOT_CHECK_FOR_UPDATES';
      reject(updateStatus);
    }
    if (!updateService.canApplyUpdates) {
      updateStatus["updateStatusCode"] = 'CANNOT_APPLY_UPDATES';
      reject(updateStatus);
    }
    if (updateService.canUsuallyStageUpdates) {
      if (!updateService.canStageUpdates) {
        updateStatus["updateStatusCode"] = 'CANNOT_STAGE_UPDATES';
        reject(updateStatus);
      }
    }
    if ((updateService.isOtherInstanceHandlingUpdates) && (updateService.isOtherInstanceHandlingUpdates())) {
      updateStatus["updateStatusCode"] = 'ANOTHER_INSTANCE_IS_HANDLING_UPDATES';
      reject(updateStatus);
    }
    let updateChecker = Components.classes["@mozilla.org/updates/update-checker;1"].createInstance(Components.interfaces.nsIUpdateChecker);
    if (updateChecker.stopCurrentCheck) {
      updateChecker.stopCurrentCheck();
    }
    let updateServiceListener = {
      onCheckComplete: (request, updates) => {
        latestUpdate = updateService.selectUpdate(updates, true);
        updateStatus["numberOfUpdates"] = updates.length;
        if (latestUpdate === null) {
          updateStatus["updateStatusCode"] = 'NO_UPDATES_AVAILABLE';
          reject(updateStatus);
        } else {
          for (key in latestUpdate) {
            if (typeof latestUpdate[key] !== 'function') {
              updateStatus[key] = latestUpdate[key];
            }
          }
          let result = updateService.downloadUpdate(latestUpdate, false);
          let updateProcessor = Components.classes["@mozilla.org/updates/update-processor;1"].createInstance(Components.interfaces.nsIUpdateProcessor);
          if (updateProcessor.fixUpdateDirectoryPermissions) {
            updateProcessor.fixUpdateDirectoryPermissions(true);
          }
          updateProcessor.processUpdate(latestUpdate);

          let previousState = null;
          function nowPending() {
            if ((latestUpdate.state) && ((previousState == null) || (previousState != latestUpdate.state))) {
              console.log("Update status is now " + latestUpdate.state);
            }
            previousState = latestUpdate.state;
            updateStatus["state"] = latestUpdate.state;
            updateStatus["statusText"] = latestUpdate.statusText;
            if ((latestUpdate.state == 'pending') || (latestUpdate.state == 'pending-service')) {
              updateStatus["updateStatusCode"] = 'PENDING_UPDATE';
              resolve(updateStatus);
            } else {
              setTimeout(function() { nowPending() }, 500);
            }
          }
          setTimeout(function() { nowPending() }, 500);
        }
      },
      onError: (request, update) => {
        updateStatus["updateStatusCode"] = 'UPDATE_SERVER_ERROR';
        reject(updateStatus);
      },
      QueryInterface: (ChromeUtils.generateQI ? ChromeUtils.generateQI([Components.interfaces.nsIUpdateCheckListener]) : XPCOMUtils.generateQI([Components.interfaces.nsIUpdateCheckListener])),
    };
    updateChecker.checkForUpdates(updateServiceListener, true);
  } else {
    updateStatus["updateStatusCode"] = 'UPDATE_MANAGER_DISABLED';
    reject(updateStatus);
  }
});
let updateStatus = (async function() {
  return await updateManager.then(function(updateStatus) { return updateStatus }, function(updateStatus) { return updateStatus });
})();
branch.setBoolPref("app.update.disabledForTesting", disabledForTesting);
return updateStatus;
_JS_
    $self->_context($old);
    $self->timeouts($timeouts);
    my %mapping = (
        updateStatusCode   => 'update_status_code',
        installDate        => 'install_date',
        statusText         => 'status_text',
        appVersion         => 'app_version',
        displayVersion     => 'display_version',
        promptWaitTime     => 'prompt_wait_time',
        buildID            => 'build_id',
        previousAppVersion => 'previous_app_version',
        patchCount         => 'patch_count',
        serviceURL         => 'service_url',
        selectedPatch      => 'selected_patch',
        numberOfUpdates    => 'number_of_updates',
        detailsURL         => 'details_url',
        elevationFailure   => 'elevation_failure',
        isCompleteUpdate   => 'is_complete_update',
        errorCode          => 'error_code',
        state              => 'update_state',
    );

    foreach my $key ( sort { $a cmp $b } keys %{$update_parameters} ) {
        if ( defined $mapping{$key} ) {
            $update_parameters->{ $mapping{$key} } =
              delete $update_parameters->{$key};
        }
    }
    my $update_status =
      Firefox::Marionette::UpdateStatus->new( %{$update_parameters} );
    if ( $update_status->successful() ) {
        $self->restart();
    }
    return $update_status;
}

sub _strip_pem_prefix_whitespace_and_postfix {
    my ( $self, $pem_encoded_string ) = @_;
    my $stripped_certificate;
    if (   ( $pem_encoded_string =~ s/^\-{5}BEGIN[ ]CERTIFICATE\-{5}\s*//smx )
        && ( $pem_encoded_string =~ s/\s*\-{5}END[ ]CERTIFICATE\-{5}\s*//smx ) )
    {
        $stripped_certificate = join q[], split /\s+/smx, $pem_encoded_string;
    }
    else {
        Firefox::Marionette::Exception->throw(
            'Certificate must be PEM encoded');
    }
    return $stripped_certificate;
}

sub add_certificate {
    my ( $self, %parameters ) = @_;
    my $trust = $parameters{trust} ? $parameters{trust} : _DEFAULT_CERT_TRUST();
    my $import_certificate;
    if ( $parameters{string} ) {
        $import_certificate = $self->_strip_pem_prefix_whitespace_and_postfix(
            $parameters{string} );
    }
    elsif ( $parameters{path} ) {
        my $pem_encoded_certificate =
          $self->_read_certificate_from_disk( $parameters{path} );
        $import_certificate = $self->_strip_pem_prefix_whitespace_and_postfix(
            $pem_encoded_certificate);
    }
    else {
        Firefox::Marionette::Exception->throw(
'No certificate has been supplied.  Please use the string or path parameters'
        );
    }
    $self->_import_certificate( $import_certificate, $trust );
    return $self;
}

sub _certificate_interface_preamble {
    my ($self) = @_;

    return <<'_JS_';
let certificateNew = Components.classes["@mozilla.org/security/x509certdb;1"].getService(Components.interfaces.nsIX509CertDB);
let certificateDatabase = certificateNew;
try {
    certificateDatabase = Components.classes["@mozilla.org/security/x509certdb;1"].getService(Components.interfaces.nsIX509CertDB2);
} catch (e) {
}
_JS_
}

sub _import_certificate {
    my ( $self, $certificate, $trust ) = @_;

    # security/manager/ssl/nsIX509CertDB.idl
    my $old                 = $self->_context('chrome');
    my $encoded_certificate = URI::Escape::uri_escape($certificate);
    my $encoded_trust       = URI::Escape::uri_escape($trust);
    my $result              = $self->script(
        $self->_compress_script(
            $self->_certificate_interface_preamble() . <<"_JS_") );
certificateDatabase.addCertFromBase64(decodeURIComponent("$encoded_certificate"), decodeURIComponent("$encoded_trust"), "");
_JS_
    $self->_context($old);
    return $result;
}

sub certificate_as_pem {
    my ( $self, $certificate ) = @_;

    # security/manager/ssl/nsIX509CertDB.idl
    # security/manager/ssl/nsIX509Cert.idl
    my $encoded_db_key = URI::Escape::uri_escape( $certificate->db_key() );
    my $old            = $self->_context('chrome');
    my $certificate_base64_string = MIME::Base64::encode_base64(
        (
            pack 'C*',
            @{
                $self->script(
                    $self->_compress_script(
                        $self->_certificate_interface_preamble()
                          . <<"_JS_") ) } ), q[] );
return certificateDatabase.findCertByDBKey(decodeURIComponent("$encoded_db_key"), {}).getRawDER({});
_JS_
    $self->_context($old);

    my $certificate_in_pem_form =
        "-----BEGIN CERTIFICATE-----\n"
      . ( join "\n", unpack '(A64)*', $certificate_base64_string )
      . "\n-----END CERTIFICATE-----\n";
    return $certificate_in_pem_form;
}

sub delete_certificate {
    my ( $self, $certificate ) = @_;

    # security/manager/ssl/nsIX509CertDB.idl
    my $encoded_db_key = URI::Escape::uri_escape( $certificate->db_key() );
    my $old            = $self->_context('chrome');
    my $certificate_base64_string = $self->script(
        $self->_compress_script(
            $self->_certificate_interface_preamble() . <<"_JS_") );
let certificate = certificateDatabase.findCertByDBKey(decodeURIComponent("$encoded_db_key"), {});
return certificateDatabase.deleteCertificate(certificate);
_JS_
    $self->_context($old);
    return $self;
}

sub is_trusted {
    my ( $self, $certificate ) = @_;
    my $db_key = $certificate->db_key();
    chomp $db_key;
    my $encoded_db_key = URI::Escape::uri_escape($db_key);
    my $old            = $self->_context('chrome');
    my $trusted        = $self->script(
        $self->_compress_script(
            $self->_certificate_interface_preamble()
              . <<'_JS_'), args => [$encoded_db_key] );
let certificate = certificateDatabase.findCertByDBKey(decodeURIComponent(arguments[0]), {});
if (certificateDatabase.isCertTrusted(certificate, Components.interfaces.nsIX509Cert.CA_CERT, Components.interfaces.nsIX509CertDB.TRUSTED_SSL)) {
    return true;
} else {
    return false;
}
_JS_
    $self->_context($old);
    return $trusted ? 1 : 0;
}

sub certificates {
    my ($self)       = @_;
    my $old          = $self->_context('chrome');
    my $certificates = $self->script(
        $self->_compress_script(
            $self->_certificate_interface_preamble() . <<'_JS_') );
let result = certificateDatabase.getCerts();
if (Array.isArray(result)) {
    return result;
} else {
    let certEnum = result.getEnumerator();
    let certificates = new Array();
    while(certEnum.hasMoreElements()) {
        certificates.push(certEnum.getNext().QueryInterface(Components.interfaces.nsIX509Cert));
    }
    return certificates;
}
_JS_
    $self->_context($old);
    my @certificates;
    foreach my $certificate ( @{$certificates} ) {
        push @certificates, Firefox::Marionette::Certificate->new($certificate);
    }
    return @certificates;
}

sub _read_certificate_from_disk {
    my ( $self, $path ) = @_;
    my $handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
      or Firefox::Marionette::Exception->throw(
        "Failed to open certificate '$path' for reading:$EXTENDED_OS_ERROR");
    my $certificate = $self->_read_and_close_handle( $handle, $path );
    return $certificate;
}

sub _read_certificates_from_disk {
    my ( $self, $trust ) = @_;
    my @certificates;
    if ($trust) {
        if ( ref $trust eq 'ARRAY' ) {
            foreach my $path ( @{$trust} ) {
                my $certificate = $self->_read_certificate_from_disk($path);
                push @certificates, $certificate;
            }
        }
        else {
            my $certificate = $self->_read_certificate_from_disk($trust);
            push @certificates, $certificate;
        }
    }
    return @certificates;
}

sub _setup_shortcut_proxy {
    my ( $self, $proxy_parameter, $capabilities ) = @_;
    my $firefox_proxy;
    if ( ref $proxy_parameter eq 'ARRAY' ) {
        $firefox_proxy =
          Firefox::Marionette::Proxy->new( pac =>
              Firefox::Marionette::Proxy->get_inline_pac( @{$proxy_parameter} )
          );
    }
    elsif ( $proxy_parameter->isa('Firefox::Marionette::Proxy') ) {
        $firefox_proxy = $proxy_parameter;
    }
    else {
        my $proxy_uri = URI->new($proxy_parameter);
        if ( $proxy_uri->scheme() eq 'https' ) {
            $firefox_proxy =
              Firefox::Marionette::Proxy->new( tls => $proxy_uri->host_port() );
        }
        elsif ( $proxy_uri =~ /^socks([45])?:\/\/([^\/]+)/smx ) {
            my ( $protocol_version, $host_port ) = ( $1, $2 );
            $firefox_proxy = Firefox::Marionette::Proxy->new(
                socks_protocol => $protocol_version,
                socks          => $host_port
            );
        }
        else {
            $firefox_proxy =
              Firefox::Marionette::Proxy->new(
                host => $proxy_uri->host_port() );
        }
    }
    $capabilities->{proxy} = $firefox_proxy;
    return $capabilities;
}

sub _launch_and_connect {
    my ( $self, %parameters ) = @_;
    my ( $session_id, $capabilities );
    if ( $parameters{reconnect} ) {

        ( $session_id, $capabilities ) = $self->_reconnect(%parameters);
    }
    else {
        my @certificates =
          $self->_read_certificates_from_disk( $parameters{trust} );
        my @arguments = $self->_setup_arguments(%parameters);
        $self->_import_profile_paths(%parameters);
        $self->_launch(@arguments);
        my $socket = $self->_setup_local_connection_to_firefox(@arguments);
        if ( my $proxy_parameter = delete $parameters{proxy} ) {
            if ( !$parameters{capabilities} ) {
                $parameters{capabilities} =
                  Firefox::Marionette::Capabilities->new();
            }
            $parameters{capabilities} =
              $self->_setup_shortcut_proxy( $proxy_parameter,
                $parameters{capabilities} );
        }
        ( $session_id, $capabilities ) =
          $self->_initial_socket_setup( $socket, $parameters{capabilities} );
        foreach my $certificate (@certificates) {
            $self->add_certificate(
                string => $certificate,
                trust  => _DEFAULT_CERT_TRUST()
            );
        }
        if ( $parameters{bookmarks} ) {
            $self->import_bookmarks( $parameters{bookmarks} );
        }
    }
    return ( $session_id, $capabilities );
}

sub _check_protocol_version_and_pid {
    my ( $self, $session_id, $capabilities ) = @_;
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
    return;
}

sub _post_launch_checks_and_setup {
    my ( $self, $timeouts ) = @_;
    $self->_write_local_proxy( $self->_ssh() );
    if ( defined $timeouts ) {
        $self->timeouts($timeouts);
    }
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
        print {$handle}
          MIME::Base64::decode_base64(
            Firefox::Marionette::Extension::HarExportTrigger->as_string() )
          or Firefox::Marionette::Exception->throw(
            "Failed to write to '$path':$EXTENDED_OS_ERROR");
        close $handle
          or Firefox::Marionette::Exception->throw(
            "Failed to close '$path':$EXTENDED_OS_ERROR");
        $self->install( $path, 0 );
    }
    if ( $self->{force_webauthn} ) {
        $self->{$webauthn_default_authenticator_key_name} =
          $self->add_webauthn_authenticator();
    }
    elsif ( defined $self->{force_webauthn} ) {
    }
    elsif ( $self->_is_webauthn_okay() ) {
        $self->{$webauthn_default_authenticator_key_name} =
          $self->add_webauthn_authenticator();
    }
    if ( my $geo = delete $self->{geo} ) {
        $self->_setup_geo($geo);
    }
    return;
}

sub new {
    my ( $class, %parameters ) = @_;
    my $self = $class->_init(%parameters);
    my ( $session_id, $capabilities ) = $self->_launch_and_connect(%parameters);
    $self->_check_protocol_version_and_pid( $session_id, $capabilities );
    my $timeouts = $self->_build_timeout_from_parameters(%parameters);
    $self->_post_launch_checks_and_setup($timeouts);
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
            $root_directory = $self->ssh_local_directory();
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

sub har {
    my ($self) = @_;
    my $context = $self->_context('content');
    if ( $self->{_har} ) {
        while (
            !$self->script(
                'if (window.HAR && window.HAR.triggerExport) { return 1 }')
          )
        {
            sleep 1;
        }
    }
    my $log = $self->script(<<'_JS_');
return (async function() { return await window.HAR.triggerExport() })();
_JS_
    $self->_context($context);
    return { log => $log };
}

sub _build_timeout_from_parameters {
    my ( $self, %parameters ) = @_;
    my $timeouts;
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
        $timeouts = Firefox::Marionette::Timeouts->new(
            page_load => $page_load,
            script    => $script,
            implicit  => $implicit,
        );
    }
    elsif ( $parameters{timeouts} ) {
        $timeouts = $parameters{timeouts};
    }
    return $timeouts;
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
        if ( !$self->_visible() ) {
            Carp::carp('Unable to launch firefox with -headless option');
        }
        $self->{visible} = 1;
    }
    elsif ( $self->_visible() ) {
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

sub _restart_profile_directory {
    my ($self) = @_;
    my $profile_directory = $self->{_profile_directory};
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
    return $profile_directory;
}

sub _get_remote_profile_directory {
    my ( $self, $profile_name ) = @_;
    my $profile_directory;
    if (   ( $self->_remote_uname() eq 'cygwin' )
        || ( $self->_remote_uname() eq 'MSWin32' ) )
    {
        my $appdata_directory =
          $self->_get_remote_environment_variable_via_ssh('APPDATA');
        if ( $self->_remote_uname() eq 'cygwin' ) {
            $appdata_directory =~ s/\\/\//smxg;
            $appdata_directory =
              $self->_execute_via_ssh( {}, 'cygpath', '-u',
                $appdata_directory );
            chomp $appdata_directory;
        }
        my $profile_ini_directory =
          $self->_remote_catfile( $appdata_directory, 'Mozilla', 'Firefox' );
        my $profile_ini_path =
          $self->_remote_catfile( $profile_ini_directory, 'profiles.ini' );
        my $handle = $self->_get_file_via_scp( {}, $profile_ini_path,
            'profiles.ini file' );
        my $config = Config::INI::Reader->read_handle($handle);
        $profile_directory = $self->_remote_catfile(
            Firefox::Marionette::Profile->directory(
                $profile_name, $config, $profile_ini_directory
            )
        );
    }
    else {
        my $profile_ini_directory;
        if ( $self->_remote_uname() eq 'darwin' ) {
            $profile_ini_directory = $self->_remote_catfile( 'Library',
                'Application Support', 'Firefox' );
        }
        else {
            $profile_ini_directory =
              $self->_remote_catfile( '.mozilla', 'firefox' );
        }
        my $profile_ini_path =
          $self->_remote_catfile( $profile_ini_directory, 'profiles.ini' );
        my $handle = $self->_get_file_via_scp( { ignore_exit_status => 1 },
            $profile_ini_path, 'profiles.ini file' )
          or Firefox::Marionette::Exception->throw( 'Failed to find the file '
              . $self->_ssh_address()
              . ":$profile_ini_path which would indicate where the prefs.js file for the '$profile_name' is stored"
          );
        my $config = Config::INI::Reader->read_handle($handle);
        $profile_directory = $self->_remote_catfile(
            Firefox::Marionette::Profile->directory(
                $profile_name,          $config,
                $profile_ini_directory, $self->_ssh_address()
            )
        );
    }
    return $profile_directory;
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
    if ( defined $self->{console} ) {
        push @arguments, '--jsconsole';
    }
    if ( ( defined $self->{debug} ) && ( $self->{debug} !~ /^[01]$/smx ) ) {
        push @arguments, '-MOZ_LOG=' . $self->{debug};
    }
    push @arguments, $self->_check_addons(%parameters);
    push @arguments, $self->_check_visible(%parameters);
    push @arguments, $self->_profile_arguments(%parameters);
    if ( ( $self->{_har} ) || ( $parameters{devtools} ) ) {
        push @arguments, '--devtools';
    }
    if ( $parameters{kiosk} ) {
        push @arguments, '--kiosk';
    }
    return @arguments;
}

sub _profile_arguments {
    my ( $self, %parameters ) = @_;
    my @arguments;
    if ( $parameters{restart} ) {
        push @arguments,
          (
            '-profile',    $self->_restart_profile_directory(),
            '--no-remote', '--new-instance'
          );
    }
    elsif ( $parameters{profile_name} ) {
        $self->{profile_name} = $parameters{profile_name};
        if ( $self->_ssh() ) {
            $self->{_profile_directory} =
              $self->_get_remote_profile_directory( $parameters{profile_name} );
            $self->{profile_path} =
              $self->_remote_catfile( $self->{_profile_directory}, 'prefs.js' );
        }
        else {
            $self->{_profile_directory} =
              Firefox::Marionette::Profile->directory(
                $parameters{profile_name} );
            $self->{profile_path} =
              File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
        }
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
        my $mime_types_content = $self->_mime_types_content();
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
            print {$handle} $mime_types_content
              or Firefox::Marionette::Exception->throw(
                "Failed to write to '$path':$EXTENDED_OS_ERROR");
            close $handle
              or Firefox::Marionette::Exception->throw(
                "Failed to close '$path':$EXTENDED_OS_ERROR");
        }
        push @arguments,
          ( '-profile', $profile_directory, '--no-remote', '--new-instance' );
    }
    return @arguments;
}

sub _mime_types_content {
    my ($self) = @_;
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
    return $mime_types_content;
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

sub _is_webauthn_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_WEBAUTHN()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
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

sub _is_modern_switch_window_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_MODERN_SWITCH()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_modern_go_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_MODERN_GO()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_script_missing_args_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_SCRIPT_WO_ARGS()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_script_script_parameter_okay {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_SCRIPT_SCRIPT()
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub _is_using_webdriver_ids_exclusively {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_FOR_WEBDRIVER_IDS()
        )
      )
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
        if ( $self->{pale_moon} ) {
            return 0;
        }
        else {
            return 1;
        }
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

sub _setup_parameters_for_execute_via_ssh {
    my ( $self, $ssh ) = @_;
    my $parameters = {};
    if ( !defined $ssh->{ssh_connections_to_host} ) {
        $parameters->{accept_new} = 1;
    }
    if ( !$ssh->{control_established} ) {
        $parameters->{master} = 1;
    }
    return $parameters;
}

sub execute {
    my ( $self, $binary, @arguments ) = @_;
    if ( my $ssh = $self->_ssh() ) {
        my $parameters = $self->_setup_parameters_for_execute_via_ssh($ssh);
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
        if ( $self->debug() ) {
            warn q[** ] . ( join q[ ], $binary, @arguments ) . "\n";
        }
        my ( $writer, $reader, $error );
        $error = Symbol::gensym();
        my $pid;
        eval {
            $pid =
              IPC::Open3::open3( $writer, $reader, $error, $binary,
                @arguments );
        } or do {
            chomp $EVAL_ERROR;
            Firefox::Marionette::Exception->throw(
                "Failed to execute '$binary':$EVAL_ERROR");
        };
        $writer->autoflush(1);
        $reader->autoflush(1);
        $error->autoflush(1);
        my ( $result, $output );
        while ( $result = sysread $reader,
            my $buffer, _READ_LENGTH_OF_OPEN3_OUTPUT() )
        {
            $output .= $buffer;
        }
        defined $result
          or
          Firefox::Marionette::Exception->throw( q[Failed to read STDOUT from ']
              . ( join q[ ], $binary, @arguments )
              . "':$EXTENDED_OS_ERROR" );
        while ( $result = sysread $error,
            my $buffer, _READ_LENGTH_OF_OPEN3_OUTPUT() )
        {
        }
        defined $result
          or
          Firefox::Marionette::Exception->throw( q[Failed to read STDERR from ']
              . ( join q[ ], $binary, @arguments )
              . "':$EXTENDED_OS_ERROR" );
        close $writer
          or Firefox::Marionette::Exception->throw(
            "Failed to close STDIN for $binary:$EXTENDED_OS_ERROR");
        close $reader
          or Firefox::Marionette::Exception->throw(
            "Failed to close STDOUT for $binary:$EXTENDED_OS_ERROR");
        close $error
          or Firefox::Marionette::Exception->throw(
            "Failed to close STDERR for $binary:$EXTENDED_OS_ERROR");
        waitpid $pid, 0;

        if ( $CHILD_ERROR == 0 ) {
        }
        else {
            Firefox::Marionette::Exception->throw( q[Failed to execute ']
                  . ( join q[ ], $binary, @arguments ) . q[':]
                  . $self->_error_message( $binary, $CHILD_ERROR ) );
        }
        if ( defined $output ) {
            chomp $output;
            $output =~ s/\r$//smx;
            return $output;
        }
    }
    return;
}

sub _adb_serial {
    my ($self) = @_;
    my $adb = $self->_adb();
    return join q[:], $adb->{host}, $adb->{port};
}

sub _initialise_adb {
    my ($self) = @_;
    $self->execute( 'adb', 'connect', $self->_adb_serial() );
    my $adb_regex = qr/package:(.*(firefox|fennec|fenix).*)/smx;
    my $binary    = 'adb';
    my @arguments =
      ( qw(-s), $self->_adb_serial(), qw(shell pm list packages) );
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
      ( $self->_ssh_arguments( %{$parameters} ), $self->_ssh_address() );
    my $output = $self->_get_local_command_output( $parameters, $ssh_binary,
        @ssh_arguments, $binary, @arguments );
    return $output;
}

sub _read_and_close_handle {
    my ( $self, $handle, $path ) = @_;
    my $content;
    my $result;
    while ( $result = $handle->read( my $buffer, _LOCAL_READ_BUFFER_SIZE() ) ) {
        $content .= $buffer;
    }
    defined $result
      or Firefox::Marionette::Exception->throw(
        "Failed to read from '$path':$EXTENDED_OS_ERROR");
    close $handle
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$path':$EXTENDED_OS_ERROR");
    return $content;
}

sub _catfile {
    my ( $self, $base_directory, @parts ) = @_;
    my $path;
    if ( $self->_ssh() ) {
        $path = $self->_remote_catfile( $base_directory, @parts );
    }
    else {
        $path = File::Spec->catfile( $base_directory, @parts );
    }
    return $path;
}

sub _find_win32_active_update_xml {
    my ( $self, $update_directory ) = @_;
    foreach
      my $tainted_id ( $self->_directory_listing( {}, $update_directory, 1 ) )
    {
        if ( $tainted_id =~ /^([A-F\d]{16})$/smx ) {
            my ($id) = ($1);
            my $sub_directory_path = $self->_catfile( $update_directory, $id );
            if (
                my $found = $self->_find_active_update_xml_in_directory(
                    $sub_directory_path)
              )
            {
                return $found;
            }
        }
    }
    return;
}

sub _find_active_update_xml_in_directory {
    my ( $self, $directory ) = @_;
    foreach my $entry ( $self->_directory_listing( {}, $directory, 1 ) ) {
        if ( $entry eq _ACTIVE_UPDATE_XML_FILE_NAME() ) {
            return $self->_catfile( $directory,
                _ACTIVE_UPDATE_XML_FILE_NAME() );
        }
    }
    return;
}

sub _updates_directory_exists {
    my ( $self, $base_directory ) = @_;
    if ( !$self->{_cached_per_instance}->{_update_directory} ) {
        my $common_appdata_directory;
        if ( $self->_ssh() ) {
            if (   ( $self->_remote_uname() eq 'MSWin32' )
                || ( $self->_remote_uname() eq 'cygwin' ) )
            {
                $common_appdata_directory =
                  $self->_get_remote_environment_variable_via_ssh(
                    'ALLUSERSPROFILE');
                if ( $self->_remote_uname() eq 'cygwin' ) {
                    $common_appdata_directory =~ s/\\/\//smxg;
                    $common_appdata_directory =
                      $self->_execute_via_ssh( {}, 'cygpath', '-u',
                        $common_appdata_directory );
                    chomp $common_appdata_directory;
                }
            }
        }
        elsif ( $OSNAME eq 'MSWin32' ) {
            $common_appdata_directory =
              Win32::GetFolderPath( Win32::CSIDL_COMMON_APPDATA() );
        }
        elsif ( $OSNAME ne 'cygwin' ) {
            $common_appdata_directory = $ENV{ALLUSERSPROFILE};
        }
        if (   ($common_appdata_directory)
            && ( !$self->{_cached_per_instance}->{_mozilla_update_directory} ) )
        {
            if (
                my $sub_directory = $self->_get_microsoft_updates_sub_directory(
                    $common_appdata_directory)
              )
            {
                $base_directory = $sub_directory;
                $self->{_cached_per_instance}->{_mozilla_update_directory} =
                  $base_directory;
            }
        }
        if ($base_directory) {
            foreach my $entry (
                $self->_directory_listing(
                    { ignore_missing_directory => 1 },
                    $base_directory, 1
                )
              )
            {
                if ( $entry eq 'updates' ) {
                    $self->{_cached_per_instance}->{_update_directory} =
                      $self->_remote_catfile( $base_directory, 'updates' );
                }
            }
        }
    }
    return $self->{_cached_per_instance}->{_update_directory};
}

sub _get_microsoft_updates_sub_directory {
    my ( $self, $common_appdata_directory ) = @_;
    my $sub_directory;
  ENTRY:
    foreach my $entry (
        $self->_directory_listing(
            { ignore_missing_directory => 1 },
            $common_appdata_directory, 1
        )
      )
    {
        if ( $entry =~ /^Mozilla/smx ) {
            my $first_updates_directory =
              $self->_catfile( $common_appdata_directory, $entry, 'updates' );
            foreach my $entry (
                $self->_directory_listing(
                    { ignore_missing_directory => 1 },
                    $first_updates_directory,
                    1
                )
              )
            {
                if ( $entry =~ /^[[:xdigit:]]{16}$/smx ) {
                    if (
                        my $handle = $self->_open_handle_for_reading(
                            $first_updates_directory, $entry,
                            'updates',                '0',
                            'update.status'
                        )
                      )
                    {
                        $sub_directory =
                          $self->_catfile( $first_updates_directory, $entry );
                        last ENTRY;
                    }
                }
            }
        }
    }
    return $sub_directory;
}

sub _open_handle_for_reading {
    my ( $self, @path ) = @_;
    my $path = $self->_catfile(@path);
    if ( $self->_ssh() ) {
        if (
            my $handle = $self->_get_file_via_scp(
                { ignore_exit_status => 1 },
                $path, $path[-1], ' file'
            )
          )
        {
            return $handle;
        }
    }
    else {
        if ( my $handle = FileHandle->new( $path, Fcntl::O_RDONLY() ) ) {
            return $handle;
        }
    }
    return;
}

sub _active_update_xml_path {
    my ($self) = @_;
    my $path;
    my $directory = $self->_binary_directory();
    if ( !defined $directory ) {
    }
    elsif ( $self->_ssh() ) {
        if (   ( $self->_remote_uname() eq 'MSWin32' )
            || ( $self->_remote_uname() eq 'cygwin' ) )
        {
            my $update_directory;
            if (
                (
                    $update_directory =
                    $self->_updates_directory_exists($directory)
                )
                && ( my $found =
                    $self->_find_win32_active_update_xml($update_directory) )
              )
            {
                $path = $found;
            }
        }
        else {
            if ( my $found =
                $self->_find_active_update_xml_in_directory($directory) )
            {
                $path = $found;
            }
        }
    }
    else {
        if ( ( $OSNAME eq 'MSWin32' ) || ( $OSNAME eq 'cygwin' ) ) {
            my $update_directory;
            if (
                (
                    $update_directory =
                    $self->_updates_directory_exists($directory)
                )
                && ( my $found =
                    $self->_find_win32_active_update_xml($update_directory) )
              )
            {
                $path = $found;
            }
        }
        else {
            if ( my $found =
                $self->_find_active_update_xml_in_directory($directory) )
            {
                $path = $found;
            }
        }
    }
    return $path;
}

sub _active_update_version {
    my ($self) = @_;
    my $active_update_version;
    if ( my $active_update_path = $self->_active_update_xml_path() ) {
        my $active_update_handle;
        if ( $self->_ssh() ) {
            $active_update_handle =
              $self->_get_file_via_scp( { ignore_exit_status => 1 },
                $active_update_path, _ACTIVE_UPDATE_XML_FILE_NAME() );
        }
        else {
            $active_update_handle =
              FileHandle->new( $active_update_path, Fcntl::O_RDONLY() )
              or Firefox::Marionette::Exception->throw(
"Failed to open '$active_update_path' for reading:$EXTENDED_OS_ERROR"
              );
        }
        if ($active_update_handle) {
            my $active_update_contents =
              $self->_read_and_close_handle( $active_update_handle,
                $active_update_path );
            my $parser = XML::Parser->new();
            $parser->setHandlers(
                Start => sub {
                    my ( $p, $element, %attributes ) = @_;
                    if ( $element eq 'update' ) {
                        $active_update_version = $attributes{appVersion};
                    }
                },
            );
            $parser->parse($active_update_contents);
        }
    }
    return $active_update_version;
}

sub _application_ini_config {
    my ( $self, $binary ) = @_;
    my $application_ini_path;
    my $application_ini_handle;
    my $application_ini_name = 'application.ini';
    if ( my $binary_directory = $self->_binary_directory() ) {
        if ( $self->_ssh() ) {
            if ( $self->_remote_uname() eq 'darwin' ) {
                $binary_directory =~ s/Contents\/MacOS$/Contents\/Resources/smx;
            }
            elsif ( $self->_remote_uname() eq 'cygwin' ) {
                $binary_directory =
                  $self->_execute_via_ssh( {}, 'cygpath', '-u',
                    $binary_directory );
                chomp $binary_directory;
            }
            $application_ini_path =
              $self->_catfile( $binary_directory, $application_ini_name );
            $application_ini_handle =
              $self->_get_file_via_scp( { ignore_exit_status => 1 },
                $application_ini_path, $application_ini_name );
        }
        else {
            if ( $OSNAME eq 'darwin' ) {
                $binary_directory =~ s/Contents\/MacOS$/Contents\/Resources/smx;
            }
            elsif ( $OSNAME eq 'cygwin' ) {
                if ( defined $binary_directory ) {
                    $binary_directory =
                      $self->execute( 'cygpath', '-u', $binary_directory );
                }
            }
            $application_ini_path =
              File::Spec->catfile( $binary_directory, $application_ini_name );
            $application_ini_handle =
              FileHandle->new( $application_ini_path, Fcntl::O_RDONLY() );
        }
    }
    if ($application_ini_handle) {
        my $config = Config::INI::Reader->read_handle($application_ini_handle);
        return $config;
    }
    return;
}

sub _search_for_version_in_application_ini {
    my ( $self, $binary ) = @_;
    my $active_update_version = $self->_active_update_version();
    if ( my $config = $self->_application_ini_config($binary) ) {
        if ( my $app = $config->{App} ) {
            if (
                ( $app->{SourceRepository} )
                && ( $app->{SourceRepository} eq
                    'https://hg.mozilla.org/releases/mozilla-beta' )
              )
            {
                $self->{developer_edition} = 1;
            }
            return join q[ ], $app->{Vendor}, $app->{Name},
              $active_update_version || $app->{Version};
        }
    }
    return;
}

sub _get_version_string {
    my ( $self, $binary ) = @_;
    my $version_string;
    if ( $version_string =
        $self->_search_for_version_in_application_ini($binary) )
    {
    }
    elsif ( $self->_ssh() ) {
        $version_string = $self->execute( q["] . $binary . q["], '--version' );
        $version_string =~ s/\r?\n$//smx;
    }
    else {
        $version_string = $self->execute( $binary, '--version' );
        $version_string =~ s/\r?\n$//smx;
    }
    return $version_string;
}

sub _initialise_version {
    my ($self) = @_;
    if ( defined $self->{_initial_version} ) {
    }
    else {
        $self->_get_version();
    }
    return;
}

sub _adb_package_name {
    my ($self) = @_;
    return $self->{adb_package_name};
}

sub _adb_component_name {
    my ($self) = @_;
    return join q[.], $self->_adb_package_name, q[App];
}

sub _get_version {
    my ($self) = @_;
    my $binary = $self->_binary();
    $self->{binary} = $binary;
    my $version_string;
    my $version_regex = qr/(\d+)[.](\d+(?:\w\d+|\-\d+)?)(?:[.](\d+))*/smx;
    if ( $self->_adb() ) {
        my $package_name = $self->_initialise_adb();
        my $dumpsys =
          $self->execute( 'adb', '-s', $self->_adb_serial(), 'shell',
            'dumpsys', 'package', $package_name );
        my $found;
        foreach my $line ( split /\r?\n/smx, $dumpsys ) {
            if ( $line =~ /^[ ]+versionName=$version_regex\s*$/smx ) {
                $found                             = 1;
                $self->{_initial_version}->{major} = $1;
                $self->{_initial_version}->{minor} = $2;
                $self->{_initial_version}->{patch} = $3;
            }
        }
        if ($found) {
            $self->{adb_package_name} = $package_name;
        }
        else {
            Firefox::Marionette::Exception->throw( 'adb -s '
                  . $self->_adb_serial()
                  . " shell dumpsys package $package_name' did not produce output that looks like '^[ ]+versionName=\\d+[.]\\d+([.]\\d+)?\\s*\$':$version_string"
            );
        }
    }
    else {
        $version_string = $self->_get_version_string($binary);
        my $waterfox_regex = qr/Waterfox(?:Limited)?[ ]Waterfox[ ]/smx;
        my $browser_regex  = join q[|],
          qr/Mozilla[ ]Firefox[ ]/smx,
          qr/LibreWolf[ ]Firefox[ ]/smx,
          $waterfox_regex,
          qr/Moonchild[ ]Productions[ ]Basilisk[ ]/smx,
          qr/Moonchild[ ]Productions[ ]Pale[ ]Moon[ ]/smx;
        if ( $version_string =~
            /(${browser_regex})${version_regex}[[:alpha:]]*\s*$/smx )

# not anchoring the start of the regex b/c of issues with
# RHEL6 and dbus crashing with error messages like
# 'Failed to open connection to "session" message bus: /bin/dbus-launch terminated abnormally without any error message'
        {
            my ( $browser_result, $major, $minor, $patch ) = ( $1, $2, $3, $4 );
            if ( $browser_result eq 'Moonchild Productions Pale Moon ' ) {
                $self->{pale_moon} = 1;
                $self->{_initial_version}->{major} =
                  _PALEMOON_VERSION_EQUIV();
            }
            else {
                $self->{_initial_version}->{major} = $major;
                $self->{_initial_version}->{minor} = $minor;
                $self->{_initial_version}->{patch} = $patch;
            }
            if ( $browser_result =~ /^$waterfox_regex$/smx ) {
                $self->{waterfox} = 1;
            }
        }
        elsif ( defined $self->{_initial_version} ) {
        }
        elsif ( $version_string =~ /^Waterfox(?:Limited)?[ ]/smx ) {
            $self->{waterfox} = 1;
            if ( $version_string =~ /^Waterfox Classic/smx ) {
                $self->{_initial_version}->{major} =
                  _WATERFOX_CLASSIC_VERSION_EQUIV();
            }
            else {
                $self->{_initial_version}->{major} =
                  _WATERFOX_CURRENT_VERSION_EQUIV();
            }
        }
        else {
            Carp::carp(
"'$binary --version' did not produce output that could be parsed.  Assuming modern Marionette is available"
            );
        }
    }
    $self->_validate_any_requested_version( $binary, $version_string );
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

sub debug {
    my ( $self, $new ) = @_;
    my $old = $self->{debug};
    if ( defined $new ) {
        $self->{debug} = $new;
    }
    return $old;
}

sub _visible {
    my ($self) = @_;
    return $self->{visible};
}

sub _firefox_pid {
    my ($self) = @_;
    if (   ( defined $self->{_firefox_pid} )
        && ( $self->{_firefox_pid} =~ /^(\d+)/smx ) )
    {
        return $1;
    }
    return;
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
    my ( $self, @unquoted_arguments ) = @_;
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
    my $command_line = $self->_quoting_for_cmd_exe( $binary, @arguments );
    if ( $self->debug() ) {
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
    my $binary = q["] . $self->_binary() . q["];
    if ( $self->_visible() ) {
        if (   ( $self->_remote_uname() eq 'MSWin32' )
            || ( $self->_remote_uname() eq 'darwin' )
            || ( $self->_visible() eq 'local' )
            || ( $self->_remote_uname() eq 'cygwin' ) )
        {
        }
        else {
            @arguments = (
                '-a', '-s',
                q["] . ( join q[ ], $self->_xvfb_common_arguments() ) . q["],
                $binary, @arguments,
            );
            $binary = 'xvfb-run';
        }
    }
    if ( $OSNAME eq 'MSWin32' ) {
        my $ssh_binary = $self->_get_full_short_path_for_win32_binary('ssh')
          or Firefox::Marionette::Exception->throw(
"Failed to find 'ssh' anywhere in the Path environment variable:$ENV{Path}"
          );
        my @ssh_arguments = (
            $self->_ssh_arguments( graphical => 1, env => 1 ),
            $self->_ssh_address()
        );
        my $process =
          $self->_start_win32_process( 'ssh', @ssh_arguments,
            $binary, @arguments );
        $self->{_win32_ssh_process} = $process;
        my $pid = $process->GetProcessID();
        $self->{_ssh}->{pid} = $pid;
        return $pid;
    }
    else {
        my $dev_null = File::Spec->devnull();

        if ( my $pid = fork ) {
            $self->{_ssh}->{pid} = $pid;
            return $pid;
        }
        elsif ( defined $pid ) {
            eval {
                open STDIN, q[<], $dev_null
                  or Firefox::Marionette::Exception->throw(
                    "Failed to redirect STDIN to $dev_null:$EXTENDED_OS_ERROR");
                $self->_ssh_exec(
                    $self->_ssh_arguments( graphical => 1, env => 1 ),
                    $self->_ssh_address(), $binary, @arguments )
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
            } or do {
                if ( $self->debug() ) {
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

sub _launch_via_adb {
    my ( $self, @arguments ) = @_;
    my $binary         = q[adb];
    my $package_name   = $self->_adb_package_name();
    my $component_name = $self->_adb_component_name();
    @arguments = (
        (
            qw(-s),
            $self->_adb_serial(),
            qw(shell am start -W -n),
            ( join q[/], $package_name, $component_name ),
            qw(--es),
            q[args -marionette]
        ),
    );
    $self->execute( $binary, @arguments );
    return;
}

sub _launch {
    my ( $self, @arguments ) = @_;
    $self->{_initial_arguments} = [];
    foreach my $argument (@arguments) {
        push @{ $self->{_initial_arguments} }, $argument;
    }
    local $ENV{XPCSHELL_TEST_PROFILE_DIR} = 1;
    if ( $self->_adb() ) {
        $self->_launch_via_adb(@arguments);
        return;
    }
    if ( $self->_ssh() ) {
        $self->{_local_ssh_pid} = $self->_launch_via_ssh(@arguments);
        $self->_wait_for_any_background_update_status();
        return;
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
        local $ENV{DISPLAY}    = $self->xvfb_display();
        local $ENV{XAUTHORITY} = $self->xvfb_xauthority();
        local $ENV{TMPDIR}     = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_unix(@arguments);
    }
    elsif ( $self->{_launched_xvfb_anyway} ) {
        local $ENV{DISPLAY}    = $self->xvfb_display();
        local $ENV{XAUTHORITY} = $self->xvfb_xauthority();
        local $ENV{TMPDIR}     = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_unix(@arguments);
    }
    else {
        local $ENV{TMPDIR} = $self->_local_firefox_tmp_directory();
        $self->{_firefox_pid} = $self->_launch_unix(@arguments);
    }
    $self->_wait_for_any_background_update_status();
    return;
}

sub _launch_win32 {
    my ( $self, @arguments ) = @_;
    my $binary = $self->_binary();
    if ( $binary =~ /[.]pl$/smx ) {
        unshift @arguments, $binary;
        $binary = $EXECUTABLE_NAME;
    }
    my $process = $self->_start_win32_process( $binary, @arguments );
    $self->{_win32_firefox_process} = $process;
    return $process->GetProcessID();
}

sub _xvfb_binary {
    return 'Xvfb';
}

sub _dev_fd_works {
    my ($self) = @_;
    my $test_handle = File::Temp::tempfile(
        File::Spec->catfile(
            File::Spec->tmpdir(), 'firefox_marionette_dev_fd_test_XXXXXXXXXXX'
        )
      )
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
            if ( $self->debug() ) {
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
    Carp::carp(
'**** DEPRECATED METHOD - using xvfb() HAS BEEN REPLACED BY xvfb_pid ****'
    );
    return $self->xvfb_pid();
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
    close $auth_handle
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$ENV{XAUTHORITY}':$EXTENDED_OS_ERROR");
    my $mcookie = unpack 'H*',
      Crypt::URandom::urandom( _NUMBER_OF_MCOOKIE_BYTES() );
    my $source_handle = File::Temp::tempfile(
        File::Spec->catfile(
            File::Spec->tmpdir(), 'firefox_marionette_xauth_source_XXXXXXXXXXX'
        )
      )
      or Firefox::Marionette::Exception->throw(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    fcntl $source_handle, Fcntl::F_SETFD(), 0
      or Firefox::Marionette::Exception->throw(
"Failed to clear the close-on-exec flag on a temporary file:$EXTENDED_OS_ERROR"
      );
    my $xauth_proto = q[.];
    print {$source_handle} "add :$display_number $xauth_proto $mcookie\n"
      or Firefox::Marionette::Exception->throw(
        "Failed to write to temporary file:$EXTENDED_OS_ERROR");
    seek $source_handle, 0, Fcntl::SEEK_SET()
      or Firefox::Marionette::Exception->throw(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    my $dev_null  = File::Spec->devnull();
    my $binary    = 'xauth';
    my @arguments = ( 'source', '/dev/fd/' . fileno $source_handle );

    if ( $self->debug() ) {
        warn q[** ] . ( join q[ ], $binary, @arguments ) . "\n";
    }

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
            if ( !$self->debug() ) {
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
            if ( $self->debug() ) {
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

sub xvfb_pid {
    my ($self) = @_;
    return $self->{_xvfb_pid};
}

sub xvfb_display {
    my ($self) = @_;
    return ":$self->{_xvfb_display_number}";
}

sub xvfb_xauthority {
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

sub _xvfb_directory {
    my ($self)         = @_;
    my $root_directory = $self->_root_directory();
    my $xvfb_directory = File::Spec->catdir( $root_directory, 'xvfb' );
    return $xvfb_directory;
}

sub _debug_xvfb_execution {
    my ( $self, $binary, @arguments ) = @_;
    if ( $self->debug() ) {
        warn q[** ] . ( join q[ ], $binary, @arguments ) . "\n";
    }
    return;
}

sub _xvfb_common_arguments {
    my ($self) = @_;
    my $width =
      defined $self->{window_width}
      ? $self->{window_width}
      : _DEFAULT_WINDOW_WIDTH();
    my $height =
      defined $self->{window_height}
      ? $self->{window_height}
      : _DEFAULT_WINDOW_HEIGHT();
    my $width_height_depth = join q[x], $width, $height, _DEFAULT_DEPTH();
    my @arguments          = (
        '-screen' => '0',
        $width_height_depth,
    );
    return @arguments;
}

sub _launch_xvfb {
    my ($self) = @_;
    my $xvfb_directory = $self->_xvfb_directory();
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
    my @arguments = (
        '-displayfd' => fileno $display_no_handle,
        $self->_xvfb_common_arguments(),
        '-nolisten' => 'tcp',
        '-fbdir'    => $fbdir_directory,
    );
    my $binary = $self->_xvfb_binary();
    $self->_debug_xvfb_execution( $binary, @arguments );
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
        local $ENV{DISPLAY}    = $self->xvfb_display();
        local $ENV{XAUTHORITY} = $self->xvfb_xauthority();
        if ( $self->_launch_xauth($display_number) ) {
            return 1;
        }
    }
    elsif ( defined $pid ) {
        eval {
            if ( !$self->debug() ) {
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
            if ( $self->debug() ) {
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
    if ( $self->debug() ) {
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
                if ( !$self->debug() ) {
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
                if ( $self->debug() ) {
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

sub macos_binary_paths {
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
        '/Applications/Waterfox Classic.app/Contents/MacOS/waterfox',
        '/Applications/LibreWolf.app/Contents/MacOS/librewolf',
    );
}

my %_known_win32_organisations = (
    'Mozilla Firefox'           => 'Mozilla',
    'Mozilla Firefox ESR'       => 'Mozilla',
    'Firefox Developer Edition' => 'Mozilla',
    Nightly                     => 'Mozilla',
    'Waterfox'                  => 'WaterfoxLimited',
    'Waterfox Current'          => 'Waterfox',
    'Waterfox Classic'          => 'Waterfox',
    Basilisk                    => 'Mozilla',
    'Pale Moon'                 => 'Mozilla',
);

sub win32_organisation {
    my ( $self, $name ) = @_;
    return $_known_win32_organisations{$name};
}

sub win32_product_names {
    my ($self) = @_;
    my %known_win32_preferred_names = (
        'Mozilla Firefox'           => 1,
        'Mozilla Firefox ESR'       => 2,
        'Firefox Developer Edition' => 3,
        Nightly                     => 4,
        'Waterfox'                  => 5,
        'Waterfox Current'          => 6,
        'Waterfox Classic'          => 7,
        Basilisk                    => 8,
        'Pale Moon'                 => 9,
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
                if ( $key !~ /^Waterfox/smx ) {
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
        $value = $self->_read_and_close_handle( $handle, $path );
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

sub _get_binary_from_cygwin_registry_via_ssh {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->win32_product_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE/WOW6432Node)) {
            my $organisation = $self->win32_organisation($name);
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
            my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?\0?/smx;
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

sub _get_binary_from_cygwin_registry {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->win32_product_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE/WOW6432Node)) {
            my $organisation = $self->win32_organisation($name);
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

sub _get_binary_from_win32_registry_via_ssh {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->win32_product_names();
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
            my $organisation = $self->win32_organisation($name);
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

sub _get_binary_from_local_win32_registry {
    my ($self) = @_;
    my $binary;
    my %known_win32_preferred_names = $self->win32_product_names();
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE\\WOW6432Node)) {
            my $organisation = $self->win32_organisation($name);
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

sub _get_binary_from_local_osx_filesystem {
    my ($self) = @_;
    foreach my $path ( $self->macos_binary_paths() ) {
        if ( stat $path ) {
            return $path;
        }
    }
    return;
}

sub _get_binary_from_remote_osx_filesystem {
    my ($self) = @_;
    foreach my $path ( $self->macos_binary_paths() ) {
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
        if ( !$self->{binary_from_registry} ) {
            $self->{binary_from_registry} =
              $self->_get_binary_from_win32_registry_via_ssh();
        }
        if ( $self->{binary_from_registry} ) {
            $binary = $self->{binary_from_registry};
        }
    }
    elsif ( $self->_remote_uname() eq 'darwin' ) {
        if ( !$self->{binary_from_osx_filesystem} ) {
            $self->{binary_from_osx_filesystem} =
              $self->_get_binary_from_remote_osx_filesystem();
        }
        if ( $self->{binary_from_osx_filesystem} ) {
            $binary = $self->{binary_from_osx_filesystem};
        }
    }
    elsif ( $self->_remote_uname() eq 'cygwin' ) {
        if ( !$self->{binary_from_cygwin_registry} ) {
            $self->{binary_from_cygwin_registry} =
              $self->_get_binary_from_cygwin_registry_via_ssh();
        }
        if ( $self->{binary_from_cygwin_registry} ) {
            $binary = $self->{binary_from_cygwin_registry};
        }
    }
    return $binary;
}

sub _get_local_binary {
    my ($self) = @_;
    my $binary;
    if ( $OSNAME eq 'MSWin32' ) {
        if ( !$self->{binary_from_registry} ) {
            $self->{binary_from_registry} =
              $self->_get_binary_from_local_win32_registry();
        }
        if ( $self->{binary_from_registry} ) {
            $binary = Win32::GetShortPathName( $self->{binary_from_registry} );
        }
    }
    elsif ( $OSNAME eq 'darwin' ) {
        if ( !$self->{binary_from_osx_filesystem} ) {
            $self->{binary_from_osx_filesystem} =
              $self->_get_binary_from_local_osx_filesystem();
        }
        if ( $self->{binary_from_osx_filesystem} ) {
            $binary = $self->{binary_from_osx_filesystem};
        }
    }
    elsif ( $OSNAME eq 'cygwin' ) {
        my $cygwin_binary = $self->_get_binary_from_cygwin_registry();
        if ( defined $cygwin_binary ) {
            $binary = $self->execute( 'cygpath', '-u', $cygwin_binary );
        }
    }
    return $binary;
}

sub default_binary_name {
    return 'firefox';
}

sub _binary {
    my ($self) = @_;
    my $binary = $self->default_binary_name();
    if ( $self->{marionette_binary} ) {
        $binary = $self->{marionette_binary};
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
            elsif ( ( $self->xvfb_pid() ) && ( $pid == $self->xvfb_pid() ) ) {
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
            elsif ( ( $self->xvfb_pid() ) && ( $pid == $self->xvfb_pid() ) ) {
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
    my $remote_uname = $self->_remote_uname();
    if ( !defined $remote_uname ) {
        return;
    }
    elsif ( $remote_uname eq 'MSWin32' ) {
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
    my $result = $self->_execute_via_ssh(
        { return_exit_status => 1 },
        (
            $self->_remote_uname() eq 'cygwin'
            ? ( '/bin/kill', '-W' )
            : ('kill')
        ),
        '-0',
        $remote_pid
    );
    if ( $result == 0 ) {
        $self->{last_remote_alive_status} = 1;
    }
    else {
        $self->{last_remote_alive_status} = 0;
    }
    return $self->{last_remote_alive_status};
}

sub alive {
    my ($self) = @_;
    if ( $self->_adb() ) {
        my $parameters;
        my $binary = q[adb];
        my @arguments =
          ( qw(-s), $self->_adb_serial(), qw(shell am stack list) );
        my $handle =
          $self->_get_local_handle_for_generic_command_output( $parameters,
            $binary, @arguments );
        my $quoted_package_name   = quotemeta $self->_adb_package_name();
        my $quoted_component_name = quotemeta $self->_adb_component_name();
        my $found                 = 0;
        while ( my $line = <$handle> ) {
            if ( $line =~
/^[ ]+taskId=\d+:[ ]$quoted_package_name\/${quoted_component_name}[ ]+/smx
              )
            {
                $found = 1;
            }
        }
        return $found;
    }
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
        if ( defined $self->ssh_local_directory() ) {
            my $path = File::Spec->catfile( $self->ssh_local_directory(),
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
    if ( $self->{_ssh_port_forwarding} ) {
        $self->_cancel_port_forwarding_via_ssh_with_control_path();
    }
    $self->_start_port_forwarding_via_ssh_with_control_path( $ssh_local_path,
        $localhost, $port );
    return;
}

sub _cancel_port_forwarding_via_ssh_with_control_path {
    my ($self) = @_;
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
            $self->_ssh_exec( $self->_ssh_arguments(),
                '-O', 'cancel', $self->_ssh_address() )
              or Firefox::Marionette::Exception->throw(
                "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
        } or do {
            if ( $self->debug() ) {
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

sub _start_port_forwarding_via_ssh_with_control_path {
    my ( $self, $ssh_local_path, $localhost, $port ) = @_;
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        if ( $CHILD_ERROR == 0 ) {
            $self->{_ssh_port_forwarding}->{$localhost}->{$port} = 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
                    'Failed to forward marionette port from '
                  . $self->_ssh_address() . q[:]
                  . $self->_error_message( 'ssh', $CHILD_ERROR ) );
        }
    }
    elsif ( defined $pid ) {
        eval {
            $self->_ssh_exec(
                $self->_ssh_arguments(),
                '-L', "$ssh_local_path:$localhost:$port",
                '-O', 'forward', $self->_ssh_address()
              )
              or Firefox::Marionette::Exception->throw(
                "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
        } or do {
            if ( $self->debug() ) {
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
        $self->_ssh_arguments(),
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
                if ( $self->debug() ) {
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
    my $port = $self->_get_marionette_port();
    if ( ( !defined $port ) || ( $port == 0 ) ) {
        sleep 1;
        return;
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

sub _network_connection_and_initial_read_from_marionette {
    my ( $self, $socket, $sock_addr ) = @_;
    my ( $port, $host ) = Socket::unpack_sockaddr_in($sock_addr);
    $host = Socket::inet_ntoa($host);
    my $connected;
    if ( connect $socket, $sock_addr ) {
        my $number_of_bytes = sysread $socket,
          $self->{_initial_octet_read_from_marionette_socket}, 1;
        if ($number_of_bytes) {
            $connected = 1;
        }
        elsif ( defined $number_of_bytes ) {
            sleep 1;
        }
        else {
            Firefox::Marionette::Exception->throw(
"Failed to read from connection to $host on port $port:$EXTENDED_OS_ERROR"
            );
        }
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
    return $connected;
}

sub _setup_local_connection_to_firefox {
    my ( $self, @arguments ) = @_;
    my $host = _DEFAULT_HOST();
    my $port;
    my $socket;
    my $sock_addr;
    my $connected;
    while ( ( !$connected ) && ( $self->alive() ) ) {
        if ( $self->_adb() ) {
            Firefox::Marionette::Exception->throw(
                'TODO: Cannot connect to android yet. Patches welcome');
        }
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

        $connected =
          $self->_network_connection_and_initial_read_from_marionette( $socket,
            $sock_addr );
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

sub _ssh_arguments {
    my ( $self, %parameters ) = @_;
    my @arguments = qw(-2 -a -T);
    if ( ( $parameters{graphical} ) || ( $parameters{master} ) ) {
        if ( ( defined $self->_visible() ) && ( $self->_visible() eq 'local' ) )
        {
            push @arguments, '-X';
        }
    }
    if ( my $ssh = $self->_ssh() ) {
        if ( my $port = $ssh->{port} ) {
            push @arguments, ( '-p' => $port, );
        }
    }
    return ( @arguments, $self->_ssh_common_arguments(%parameters) );
}

sub _ssh_exec {
    my ( $self, @parameters ) = @_;
    if ( $self->debug() ) {
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
                'ssh', $self->_ssh_arguments(),
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
                $self->_ssh_exec( $self->_ssh_arguments(),
                    $self->_ssh_address(), 'mkdir', @mkdir_parameters, $path )
                  or Firefox::Marionette::Exception->throw(
                    "Failed to exec 'ssh':$EXTENDED_OS_ERROR");
            } or do {
                if ( $self->debug() ) {
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

sub root_directory {
    my ($self) = @_;
    return $self->{_root_directory};
}

sub _root_directory {
    my ($self) = @_;
    if ( !defined $self->{_root_directory} ) {
        my $template_prefix = 'firefox_marionette_local_';
        if ( $self->{reconnect_index} ) {
            $template_prefix .= $self->{reconnect_index} . q[-];
        }

        my $root_directory = File::Temp->newdir(
            CLEANUP  => 0,
            TEMPLATE => File::Spec->catdir(
                File::Spec->tmpdir(),
                $template_prefix . 'X' x _NUMBER_OF_CHARS_IN_TEMPLATE()
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to create temporary directory:$EXTENDED_OS_ERROR");
        $self->{_root_directory} = $root_directory->dirname();
    }
    return $self->root_directory();
}

sub _write_local_proxy {
    my ( $self, $ssh ) = @_;
    my $local_proxy_path;
    if ( defined $ssh ) {
        $local_proxy_path =
          File::Spec->catfile( $self->ssh_local_directory(), 'reconnect' );
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
        "Failed to open '$local_proxy_path' for writing:$EXTENDED_OS_ERROR");
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
    print {$local_proxy_handle} JSON::encode_json($local_proxy)
      or Firefox::Marionette::Exception->throw(
        "Failed to write to $local_proxy_path:$EXTENDED_OS_ERROR");
    close $local_proxy_handle
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

sub _new_profile_path {
    my ($self) = @_;
    my $profile_path;
    if ( $self->_ssh() ) {
        $profile_path =
          $self->_remote_catfile( $self->{_profile_directory}, 'prefs.js' );
    }
    else {
        $profile_path =
          File::Spec->catfile( $self->{_profile_directory}, 'prefs.js' );
    }
    return $profile_path;
}

sub _setup_new_profile {
    my ( $self, $profile, %parameters ) = @_;
    $self->_setup_profile_directories($profile);
    $self->{profile_path} = $self->_new_profile_path();
    if ($profile) {
        if ( !$profile->download_directory() ) {
            my $download_directory = $self->{_download_directory};
            if ( $self->_ssh() ) {
                if ( $self->_remote_uname() eq 'cygwin' ) {
                    $download_directory =
                      $self->_execute_via_ssh( {}, 'cygpath', '-s', '-w',
                        $download_directory );
                    chomp $download_directory;
                }
            }
            elsif ( $OSNAME eq 'cygwin' ) {
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
        if ( $self->{waterfox} ) {
            $profile = Waterfox::Marionette::Profile->new(%profile_parameters);
        }
        else {
            $profile = Firefox::Marionette::Profile->new(%profile_parameters);
        }
        my $download_directory = $self->{_download_directory};
        my $bookmarks_path     = $self->_setup_empty_bookmarks();
        $self->_setup_search_json_mozlz4();
        if (   ( $self->_remote_uname() )
            && ( $self->_remote_uname() eq 'cygwin' ) )
        {
            $download_directory =
              $self->_execute_via_ssh( {}, 'cygpath', '-s', '-w',
                $download_directory );
            chomp $download_directory;
        }
        $profile->download_directory($download_directory);
        $profile->set_value( 'browser.bookmarks.file', $bookmarks_path, 1 );
        if (
            !$self->_is_firefox_major_version_at_least(
                _MIN_VERSION_FOR_LINUX_SANDBOX()
            )
          )
        {
            $profile->set_value( 'security.sandbox.content.level', 0, 0 )
              ; # https://wiki.mozilla.org/Security/Sandbox#Customization_Settings
        }

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
                q[http://localhost:] . $port . q[/v1/], 1 );
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
        my $port = $self->_get_empty_port();
        $profile->set_value( 'marionette.defaultPrefs.port', $port );
        $profile->set_value( 'marionette.port',              $port );
    }
    if ( $self->_ssh() ) {
        $self->_save_profile_via_ssh($profile);
    }
    else {
        $profile->save( $self->{profile_path} );
    }
    return $self->{_profile_directory};
}

sub _get_empty_port {
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

sub _setup_search_json_mozlz4 {
    my ($self)            = @_;
    my $profile_directory = $self->{_profile_directory};
    my $uncompressed      = <<"_JSON_";
{"version":6,"engines":[{"_name":"DuckDuckGo","_isAppProvided":true,"_metaData":{}}],"metaData":{"useSavedOrder":false}}
_JSON_
    chomp $uncompressed;

#   my $content = _MAGIC_NUMBER_MOZL4Z() . Compress::LZ4::compress($uncompressed);
    my $content = MIME::Base64::decode_base64(
'bW96THo0MAB4AAAA8Bd7InZlcnNpb24iOjYsImVuZ2luZXMiOlt7Il9uYW1lIjoiRHVjawQA9x1HbyIsIl9pc0FwcFByb3ZpZGVkIjp0cnVlLCJfbWV0YURhdGEiOnt9fV0sIhAA8AgidXNlU2F2ZWRPcmRlciI6ZmFsc2V9fQ=='
    );
    return $self->_copy_content_to_profile_directory( $content,
        'search.json.mozlz4' );
}

sub _setup_empty_bookmarks {
    my ($self)  = @_;
    my $now     = time;
    my $content = <<"_HTML_";
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
    return $self->_copy_content_to_profile_directory( $content,
        'bookmarks.html' );
}

sub _copy_content_to_profile_directory {
    my ( $self, $content, $name ) = @_;
    my $profile_directory = $self->{_profile_directory};
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
        $path = $self->_remote_catfile( $profile_directory, $name );
        $self->_put_file_via_scp( $handle, $path, $name );
        if ( $self->_remote_uname() eq 'cygwin' ) {
            $path = $self->_execute_via_ssh( {}, 'cygpath', '-l', '-w', $path );
            chomp $path;
        }
    }
    else {
        $path = File::Spec->catfile( $profile_directory, $name );
        my $handle =
          FileHandle->new( $path,
            Fcntl::O_CREAT() | Fcntl::O_EXCL() | Fcntl::O_WRONLY() )
          or Firefox::Marionette::Exception->throw(
            "Failed to open '$path' for writing:$EXTENDED_OS_ERROR");
        print {$handle} $content
          or Firefox::Marionette::Exception->throw(
            "Failed to write to $path:$EXTENDED_OS_ERROR");
        close $handle
          or Firefox::Marionette::Exception->throw(
            "Failed to close '$path':$EXTENDED_OS_ERROR");
        if ( $OSNAME eq 'cygwin' ) {
            $path = $self->execute( 'cygpath', '-s', '-w', $path );
            chomp $path;
        }
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
        exit 1;
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to fork:$EXTENDED_OS_ERROR");
    }
    return $handle;
}

sub _get_local_command_output {
    my ( $self, $parameters, $binary, @arguments ) = @_;
    local $SIG{PIPE} = 'IGNORE';
    my $output;
    my $handle;
    if ( $OSNAME eq 'MSWin32' ) {
        my $shell_command = $self->_quoting_for_cmd_exe( $binary, @arguments );
        if ( $parameters->{capture_stderr} ) {
            $shell_command = "\"$shell_command 2>&1\"";
        }
        else {
            $shell_command .= ' 2>nul';
        }
        if ( $self->debug() ) {
            warn q[** ] . $shell_command . "\n";
        }
        $handle = FileHandle->new("$shell_command |");
    }
    else {
        if ( $self->debug() ) {
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
      or $parameters->{ignore_exit_status}
      or $parameters->{return_exit_status}
      or Firefox::Marionette::Exception->throw( "Failed to read from $binary "
          . ( join q[ ], @arguments )
          . ":$EXTENDED_OS_ERROR" );
    close $handle
      or $parameters->{ignore_exit_status}
      or $parameters->{return_exit_status}
      or Firefox::Marionette::Exception->throw( q[Command ']
          . ( join q[ ], $binary, @arguments )
          . q[ did not complete successfully:]
          . $self->_error_message( $binary, $CHILD_ERROR ) );
    if ( $parameters->{return_exit_status} ) {
        return $CHILD_ERROR;
    }
    else {
        return $output;
    }
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
            if ( $line =~
                /^OpenSSH(?:_for_Windows)?_(\d+[.]\d+(?:p\d+)?)[ ,]/smx )
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

sub _scp_arguments {
    my ( $self, %parameters ) = @_;
    my @arguments = qw(-p);
    if ( $self->{force_scp_protocol} ) {
        push @arguments, qw(-O);
    }
    if ( $self->_scp_t_ok() ) {
        push @arguments, qw(-T);
    }
    if ( my $ssh = $self->_ssh() ) {
        if ( my $port = $ssh->{port} ) {
            push @arguments, ( '-P' => $port, );
        }
    }
    return ( @arguments, $self->_ssh_common_arguments(%parameters) );
}

sub _ssh_common_arguments {
    my ( $self, %parameters ) = @_;
    my @arguments = (
        '-q',
        '-o' => 'ServerAliveInterval=15',
        '-o' => 'BatchMode=yes',
        '-o' => 'ExitOnForwardFailure=yes',
    );
    if ( $self->{ssh_via_host} ) {
        push @arguments, ( '-o' => 'ProxyJump=' . $self->{ssh_via_host} );
    }
    if (   ( $parameters{master} )
        || ( $parameters{env} ) )
    {
        push @arguments, ( '-o' => 'SendEnv=TMPDIR' );
    }
    if ( $parameters{accept_new} ) {
        push @arguments, ( '-o' => 'StrictHostKeyChecking=accept-new' );
    }
    else {
        push @arguments, ( '-o' => 'StrictHostKeyChecking=yes' );
    }
    if (   ( $parameters{master} )
        && ( $self->{_ssh} )
        && ( $self->{_ssh}->{use_control_path} ) )
    {
        push @arguments,
          (
            '-o' => 'ControlPath=' . $self->_control_path(),
            '-o' => 'ControlMaster=yes',
            '-o' => 'ControlPersist=30',
          );
    }
    elsif ( ( $self->{_ssh} ) && ( $self->{_ssh}->{use_control_path} ) ) {
        push @arguments,
          (
            '-o' => 'ControlPath=' . $self->_control_path(),
            '-o' => 'ControlMaster=no',
          );
    }
    return @arguments;
}

sub _system {
    my ( $self, $parameters, $binary, @arguments ) = @_;
    my $command_line;
    my $result;
    if ( $OSNAME eq 'MSWin32' ) {
        $command_line = $self->_quoting_for_cmd_exe( $binary, @arguments );
        if ( $self->_execute_win32_process( $binary, @arguments ) ) {
            $result = 1;
        }
        else {
            $result = 0;
        }
    }
    else {
        local $SIG{PIPE} = 'IGNORE';
        my $dev_null = File::Spec->devnull();
        $command_line = join q[ ], $binary, @arguments;
        if ( $self->debug() ) {
            warn q[** ] . $command_line . "\n";
        }
        if ( my $pid = fork ) {
            waitpid $pid, 0;
            if ( $CHILD_ERROR == 0 ) {
                $result = 1;
            }
            elsif ( $parameters->{ignore_exit_status} ) {
                $result = 0;
            }
            else {
                Firefox::Marionette::Exception->throw(
                    "Failed to successfully execute $command_line:"
                      . $self->_error_message( $binary, $CHILD_ERROR ) );
            }
        }
        elsif ( defined $pid ) {
            eval {
                if ( !$self->debug() ) {
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
                if ( $self->debug() ) {
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
    return $result;
}

sub _get_file_via_scp {
    my ( $self, $parameters, $remote_path, $description ) = @_;
    $self->{_scp_get_file_index} += 1;
    my $local_name = 'file_' . $self->{_scp_get_file_index} . '.dat';
    my $local_path =
      File::Spec->catfile( $self->{_local_scp_get_directory}, $local_name );
    if (   ( $self->_remote_uname() eq 'MSWin32' )
        && ( $remote_path !~ /^[[:alnum:]:\-+\\\/.]+$/smx ) )
    {
        $remote_path = $self->_execute_via_ssh( {},
            q[for %A in ("] . $remote_path . q[") do ] . q[@] . q[echo %~sA] );
        chomp $remote_path;
        $remote_path =~ s/\r$//smx;
    }
    if ( $OSNAME eq 'MSWin32' ) {
        $remote_path = $self->_quoting_for_cmd_exe($remote_path);
    }
    else {
        if (   ( $self->_remote_uname() eq 'MSWin32' )
            || ( $self->_remote_uname() eq 'cygwin' ) )
        {
            $remote_path =~ s/\\/\//smxg;
        }
    }
    $remote_path =~ s/[ ]/\\ /smxg;
    my @arguments = (
        $self->_scp_arguments(),
        $self->_ssh_address() . ":$remote_path", $local_path,
    );
    if ( $self->_system( $parameters, 'scp', @arguments ) ) {
        my $handle = FileHandle->new( $local_path, Fcntl::O_RDONLY() );
        if ($handle) {
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
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to open '$local_path' for reading:$EXTENDED_OS_ERROR");
        }
    }
    return;
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
        print {$temp_handle} $buffer
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
        $remote_path = $self->_quoting_for_cmd_exe($remote_path);
    }
    $remote_path =~ s/[ ]/\\ /smxg;
    my @arguments = (
        $self->_scp_arguments(),
        $local_path, $self->_ssh_address() . ":$remote_path",
    );
    $self->_system( {}, 'scp', @arguments );
    unlink $local_path
      or Firefox::Marionette::Exception->throw(
        "Failed to unlink $local_path:$EXTENDED_OS_ERROR");
    return;
}

sub _initialise_remote_uname {
    my ($self) = @_;
    if ( defined $self->{_remote_uname} ) {
    }
    elsif ( $self->_adb() ) {
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
        $handle = $self->_get_file_via_scp( { ignore_exit_status => 1 },
            $self->{profile_path}, 'profile path' );
    }
    else {
        $handle =
          $self->_search_file_via_ssh( $self->{profile_path}, 'profile path',
            [ 'marionette', 'security', ] );
    }
    my $port;
    if ( defined $handle ) {
        while ( my $line = <$handle> ) {
            if ( $line =~
                /^user_pref[(]"marionette[.]port",[ ]*(\d+)[)];\s*$/smx )
            {
                $port = $1;
            }
            elsif ( $line =~
/^user_pref[(]"$sandbox_regex",[ ]*"[{]?([^"}]+)[}]?"[)];\s*$/smx
              )
            {
                my ( $sandbox, $uuid ) = ( $1, $2 );
                $self->{_ssh}->{sandbox}->{$sandbox} = $uuid;
            }
        }
    }
    return $port;
}

sub _search_file_via_ssh {
    my ( $self, $path, $description, $patterns ) = @_;
    $path =~ s/[ ]/\\ /smxg;
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
    print {$handle} $output
      or Firefox::Marionette::Exception->throw(
        "Failed to write to temporary file:$EXTENDED_OS_ERROR");
    seek $handle, 0, Fcntl::SEEK_SET()
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
          or ( $OS_ERROR == POSIX::ENOENT() )
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
            close $profile_handle
              or Firefox::Marionette::Exception->throw(
                "Failed to close '$self->{profile_path}':$EXTENDED_OS_ERROR");
        }
        elsif (( $OSNAME eq 'MSWin32' )
            && ( $EXTENDED_OS_ERROR == _WIN32_ERROR_SHARING_VIOLATION() ) )
        {
            $port = 0;
        }
    }
    if ( defined $port ) {
    }
    else {
        $port = _DEFAULT_PORT();
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

sub _split_browser_version {
    my ($self) = @_;
    my ( $major, $minor, $patch );
    my $browser_version = $self->browser_version();
    if ( defined $browser_version ) {
        ( $major, $minor, $patch ) = split /[.]/smx, $browser_version;
    }
    return ( $major, $minor, $patch );
}

sub _check_ftp_support_for_proxy_request {
    my ( $self, $proxy, $build ) = @_;
    if ( $proxy->ftp() ) {
        my ( $major, $minor, $patch ) = $self->_split_browser_version();
        if ( ( defined $major ) && ( $major <= _MAX_VERSION_FOR_FTP_PROXY() ) )
        {
            $build->{proxyType} ||= 'manual';
            $build->{ftpProxy} = $proxy->ftp();
        }
        else {
            Carp::carp(
'**** FTP proxying is no longer supported, ignoring this request ****'
            );
        }
    }
    return $build;
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
    $build = $self->_check_ftp_support_for_proxy_request( $proxy, $build );
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
          Firefox::Marionette::Proxy::DEFAULT_SOCKS_VERSION();
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
    my @keys = (qw(all https http));
    my ( $major, $minor, $patch ) = $self->_split_browser_version();
    if ( $self->{waterfox} ) {
    }
    elsif ( ( defined $major ) && ( $major <= _MAX_VERSION_FOR_FTP_PROXY() ) ) {
        unshift @keys, qw(ftp);
    }
    foreach my $key (@keys) {
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
            if ( ( $key eq 'all' ) && ( $uri->scheme() eq 'https' ) ) {
                $build->{proxyType} = 'pac';
                $build->{proxyAutoconfigUrl} =
                  Firefox::Marionette::Proxy->get_inline_pac($uri);
            }
            else {
                $build->{ $build_key . 'Proxy' } = $uri->host_port();
            }
        }
    }
    return $self->_convert_proxy_before_request($build);
}

sub _translate_to_json_boolean {
    my ( $self, $boolean ) = @_;
    $boolean = $boolean ? JSON::true() : JSON::false();
    return $boolean;
}

sub _new_session_parameters {
    my ( $self, $capabilities ) = @_;
    my $parameters = {};
    $parameters->{capabilities}->{requiredCapabilities} =
      {};    # for Mozilla 50 (and below???)
    if (
        $self->_is_marionette_object(
            $capabilities, 'Firefox::Marionette::Capabilities'
        )
      )
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
        if (
            $self->_is_firefox_major_version_at_least(
                _MAX_VERSION_NO_POINTER_ORIGIN()
            )
          )
        {
            delete $booleans{moz_use_non_spec_compliant_pointer_origin};
        }
        foreach my $method ( sort { $a cmp $b } keys %booleans ) {
            if ( defined $capabilities->$method() ) {
                $actual->{ $booleans{$method} } =
                  $self->_translate_to_json_boolean( $capabilities->$method() );
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
    $self->{_cached_per_instance}->{_browser_version} = $new->browser_version();

    if ( ( defined $capabilities ) && ( defined $capabilities->timeouts() ) ) {
        $self->timeouts( $capabilities->timeouts() );
        $new->timeouts( $capabilities->timeouts() );
    }
    return ( $self->{session_id}, $new );
}

sub browser_version {
    my ($self) = @_;
    if ( defined $self->{_cached_per_instance}->{_browser_version} ) {
        return $self->{_cached_per_instance}->{_browser_version};
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

sub _get_moz_headless {
    my ( $self, $headless, $parameters ) = @_;
    if ( defined $parameters->{'moz:headless'} ) {
        my $firefox_headless = ${ $parameters->{'moz:headless'} } ? 1 : 0;
        if ( $firefox_headless != $headless ) {
            Firefox::Marionette::Exception->throw(
                'moz:headless has not been determined correctly');
        }
    }
    else {
        $parameters->{'moz:headless'} = $headless;
    }
    return $headless;
}

sub _create_capabilities {
    my ( $self, $parameters ) = @_;
    my $pid = $parameters->{'moz:processID'} || $parameters->{processId};
    if ( ($pid) && ( $OSNAME eq 'cygwin' ) ) {
        $pid = $self->_firefox_pid();
    }
    my $headless = $self->_visible() ? 0 : 1;
    $parameters->{'moz:headless'} =
      $self->_get_moz_headless( $headless, $parameters );
    if ( !defined $self->{_cached_per_instance}->{_page_load_timeouts_key} ) {
        if ( $parameters->{timeouts} ) {
            if ( defined $parameters->{timeouts}->{'page load'} ) {
                $self->{_cached_per_instance}->{_page_load_timeouts_key} =
                  'page load';
            }
            else {
                $self->{_cached_per_instance}->{_page_load_timeouts_key} =
                  'pageLoad';
            }
        }
        else {
            $self->{_no_timeouts_command} = {};
            $self->{_cached_per_instance}->{_page_load_timeouts_key} =
              'pageLoad';
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
            $self->{_cached_per_instance}->{_page_load_timeouts_key} =>
              $self->{_no_timeouts_command}->page_load(),
            script   => $self->{_no_timeouts_command}->script(),
            implicit => $self->{_no_timeouts_command}->implicit(),
        };
    }
    my %optional = $self->_get_optional_capabilities($parameters);

    return Firefox::Marionette::Capabilities->new(
        timeouts => Firefox::Marionette::Timeouts->new(
            page_load => $parameters->{timeouts}
              ->{ $self->{_cached_per_instance}->{_page_load_timeouts_key} },
            script   => $parameters->{timeouts}->{script},
            implicit => $parameters->{timeouts}->{implicit},
        ),
        browser_version => defined $parameters->{browserVersion}
        ? $parameters->{browserVersion}
        : $parameters->{version},
        platform_name => defined $parameters->{platformName}
        ? $parameters->{platformName}
        : $parameters->{platform},
        rotatable => (
            defined $parameters->{rotatable} and ${ $parameters->{rotatable} }
        ) ? 1 : 0,
        platform_version =>
          $self->_platform_version_from_capabilities($parameters),
        moz_profile => $parameters->{'moz:profile'}
          || $self->{_profile_directory},
        moz_process_id => $pid,
        moz_build_id   => $parameters->{'moz:buildID'}
          || $parameters->{appBuildId},
        browser_name => $parameters->{browserName},
        moz_headless => $headless,
        %optional,
    );
}

sub _platform_version_from_capabilities {
    my ( $self, $parameters ) = @_;
    return
      defined $parameters->{'moz:platformVersion'}
      ? $parameters->{'moz:platformVersion'}
      : $parameters->{platformVersion}
      , # https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/103#marionette
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
          ${ $parameters->{'moz:accessibilityChecks'} } ? 1 : 0;
    }
    if ( defined $parameters->{strictFileInteractability} ) {
        $optional{strict_file_interactability} =
          ${ $parameters->{strictFileInteractability} } ? 1 : 0;
    }
    if ( defined $parameters->{'moz:shutdownTimeout'} ) {
        $optional{moz_shutdown_timeout} = $parameters->{'moz:shutdownTimeout'};
    }
    if ( defined $parameters->{unhandledPromptBehavior} ) {
        $optional{unhandled_prompt_behavior} =
          $parameters->{unhandledPromptBehavior};
    }
    if ( defined $parameters->{setWindowRect} ) {
        $optional{set_window_rect} = ${ $parameters->{setWindowRect} } ? 1 : 0;
    }
    if ( defined $parameters->{'moz:webdriverClick'} ) {
        $optional{moz_webdriver_click} =
          ${ $parameters->{'moz:webdriverClick'} } ? 1 : 0;
    }
    if ( defined $parameters->{acceptInsecureCerts} ) {
        $optional{accept_insecure_certs} =
          ${ $parameters->{acceptInsecureCerts} } ? 1 : 0;
    }
    if ( defined $parameters->{pageLoadStrategy} ) {
        $optional{page_load_strategy} = $parameters->{pageLoadStrategy};
    }
    if ( defined $parameters->{'moz:useNonSpecCompliantPointerOrigin'} ) {
        $optional{moz_use_non_spec_compliant_pointer_origin} =
          ${ $parameters->{'moz:useNonSpecCompliantPointerOrigin'} } ? 1 : 0;
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
                    httpOnly =>
                      $self->_translate_to_json_boolean( $cookie->http_only() ),
                    secure =>
                      $self->_translate_to_json_boolean( $cookie->secure() ),
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
    my $old    = $self->_context('chrome');
    my $script = <<'_JS_';
(function() {
    let observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
    let iterator = observerService.enumerateObservers("http-on-modify-request");
    while (iterator.hasMoreElements()) {
        observerService.removeObserver(iterator.getNext(), "http-on-modify-request");
    }
})();

({
  observe: function(subject, topic, data) {
    this.onHeaderChanged(subject.QueryInterface(Components.interfaces.nsIHttpChannel), topic, data);
  },

  register: function() {
    let observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
    observerService.addObserver(this, "http-on-modify-request", false);
  },

  unregister: function() {
    let observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
    observerService.removeObserver(this, "http-on-modify-request");
  },

  onHeaderChanged: function(channel, topic, data) {
    let host = channel.URI.host;
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
}).register();
_JS_
    $self->script( $self->_compress_script($script) );
    $self->_context($old);
    return;
}

sub _compress_script {
    my ( $self, $script ) = @_;
    $script =~ s/\/[*].*?[*]\///smxg;
    $script =~ s/\b\/\/.*$//smxg;
    $script =~ s/[\r\n\t]+/ /smxg;
    $script =~ s/[ ]+/ /smxg;
    return $script;
}

sub _is_marionette_object {
    my ( $self, $element, $class ) = @_;
    if ( ( Scalar::Util::blessed($element) && ( $element->isa($class) ) ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub is_selected {
    my ( $self, $element ) = @_;
    if (
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        if (   ( $response->result()->{value} )
            && ( $response->result()->{value}->{capabilities} ) )
        {
            return $self->_create_capabilities(
                $response->result()->{value}->{capabilities} );
        }
        else {
            return $self->_create_capabilities(
                $response->result()->{capabilities} );
        }
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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

sub aria_label {    # https://bugzilla.mozilla.org/show_bug.cgi?id=1585622
    my ( $self, $element ) = @_;
    if (
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
        )
      )
    {
        Firefox::Marionette::Exception->throw(
'get_aria_label method requires a Firefox::Marionette::Element parameter'
        );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetComputedLabel'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub aria_role {    # https://bugzilla.mozilla.org/show_bug.cgi?id=1585622
    my ( $self, $element ) = @_;
    if (
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
        )
      )
    {
        Firefox::Marionette::Exception->throw(
'get_aria_role method requires a Firefox::Marionette::Element parameter'
        );
    }
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetComputedRole'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_response_result_value($response);
}

sub click {
    my ( $self, $element ) = @_;
    if (
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
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
            page_load => $response->result()
              ->{ $self->{_cached_per_instance}->{_page_load_timeouts_key} },
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
                        $self->{_cached_per_instance}
                          ->{_page_load_timeouts_key} => $new->page_load(),
                        script   => $new->script(),
                        implicit => $new->implicit()
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
        page_ranges      => 'pageRanges',
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
        next if ( $key eq 'pageRanges' );
        next if ( $key eq 'size' );
        next if ( $key eq 'raw' );
        next if ( $key eq 'scale' );
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
            $parameters{$key} =
              $self->_translate_to_json_boolean( $parameters{$key} );
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
        my $handle = File::Temp->new(
            TEMPLATE => File::Spec->catfile(
                File::Spec->tmpdir(), 'firefox_marionette_print_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
        binmode $handle;
        my $content = $self->_response_result_value($response);
        print {$handle} MIME::Base64::decode_base64($content)
          or Firefox::Marionette::Exception->throw(
            "Failed to write to temporary file:$EXTENDED_OS_ERROR");
        seek $handle, 0, Fcntl::SEEK_SET()
          or Firefox::Marionette::Exception->throw(
            "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
        return $handle;
    }
}

sub scroll {
    my ( $self, $element, $arguments ) = @_;
    if (
        !$self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
        )
      )
    {
        Firefox::Marionette::Exception->throw(
            'scroll method requires a Firefox::Marionette::Element parameter');
    }
    if ( defined $arguments ) {
        if ( ref $arguments ) {
        }
        else {
            $arguments = $self->_translate_to_json_boolean($arguments);
        }
        $self->script( 'arguments[0].scrollIntoView(arguments[1]);',
            args => [ $element, $arguments ] );
    }
    else {
        $self->script( 'arguments[0].scrollIntoView();', args => [$element] );
    }
    return $self;
}

sub selfie {
    my ( $self, $element, @remaining ) = @_;
    my $message_id = $self->_new_message_id();
    my $parameters = {};
    my %extra;
    if (
        $self->_is_marionette_object(
            $element, 'Firefox::Marionette::Element'
        )
      )
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
            $parameters->{$key} =
              $self->_translate_to_json_boolean( $extra{$key} );
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
        my $handle = File::Temp->new(
            TEMPLATE => File::Spec->catfile(
                File::Spec->tmpdir(), 'firefox_marionette_selfie_XXXXXXXXXXX'
            )
          )
          or Firefox::Marionette::Exception->throw(
            "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
        binmode $handle;
        my $content = $self->_response_result_value($response);
        $content =~ s/^data:image\/png;base64,//smx;
        print {$handle} MIME::Base64::decode_base64($content)
          or Firefox::Marionette::Exception->throw(
            "Failed to write to temporary file:$EXTENDED_OS_ERROR");
        seek $handle, 0, Fcntl::SEEK_SET()
          or Firefox::Marionette::Exception->throw(
            "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
        return $handle;
    }
}

sub current_chrome_window_handle {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_NO_CHROME_CALLS()
        )
      )
    {
        Carp::carp(
'**** DEPRECATED METHOD - using current_chrome_window_handle() HAS BEEN REPLACED BY window_handle() wrapped with appropriate context() calls ****'
        );
        my $old      = $self->context('chrome');
        my $response = $self->window_handle();
        $self->context($old);
        return $response;
    }
    else {
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
        return Firefox::Marionette::WebWindow->new( $self,
            Firefox::Marionette::WebWindow::IDENTIFIER() =>
              $self->_response_result_value($response) );
    }
}

sub chrome_window_handle {
    my ($self) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_NO_CHROME_CALLS()
        )
      )
    {
        Carp::carp(
'**** DEPRECATED METHOD - using chrome_window_handle() HAS BEEN REPLACED BY window_handle() wrapped with appropriate context() calls ****'
        );
        my $old      = $self->context('chrome');
        my $response = $self->window_handle();
        $self->context($old);
        return $response;
    }
    else {
        my $message_id = $self->_new_message_id();
        $self->_send_request(
            [
                _COMMAND(), $message_id,
                $self->_command('WebDriver:GetChromeWindowHandle')
            ]
        );
        my $response = $self->_get_response($message_id);
        return Firefox::Marionette::WebWindow->new( $self,
            Firefox::Marionette::WebWindow::IDENTIFIER() =>
              $self->_response_result_value($response) );
    }
}

sub key_down {
    my ( $self, $key ) = @_;
    return { type => 'keyDown', value => $key };
}

sub key_up {
    my ( $self, $key ) = @_;
    return { type => 'keyUp', value => $key };
}

sub pause {
    my ( $self, $duration ) = @_;
    return { type => 'pause', duration => $duration };
}

sub wheel {
    my ( $self, @parameters ) = @_;
    my %arguments;
    if (
        $self->_is_marionette_object(
            $parameters[0], 'Firefox::Marionette::Element'
        )
      )
    {
        my $origin = shift @parameters;
        %arguments = $self->_calculate_xy_from_element( $origin, %arguments );
    }
    while (@parameters) {
        my $key = shift @parameters;
        $arguments{$key} = shift @parameters;
    }
    foreach my $key (qw(x y duration deltaX deltaY)) {
        $arguments{$key} ||= 0;
    }
    return { type => 'scroll', %arguments };
}

sub mouse_move {
    my ( $self, @parameters ) = @_;
    my %arguments;
    if (
        $self->_is_marionette_object(
            $parameters[0], 'Firefox::Marionette::Element'
        )
      )
    {
        my $origin = shift @parameters;
        %arguments = $self->_calculate_xy_from_element( $origin, %arguments );
    }
    while (@parameters) {
        my $key = shift @parameters;
        $arguments{$key} = shift @parameters;
    }
    return { type => 'pointerMove', pointerType => 'mouse', %arguments };
}

sub _calculate_xy_from_element {
    my ( $self, $origin, %arguments ) = @_;
    my $rect = $origin->rect();
    $arguments{x} = $rect->pos_x() + ( $rect->width() / 2 );
    if ( $arguments{x} != int $arguments{x} ) {
        $arguments{x} = int $arguments{x} + 1;
    }
    $arguments{y} = $rect->pos_y() + ( $rect->height() / 2 );
    if ( $arguments{y} != int $arguments{y} ) {
        $arguments{y} = int $arguments{y} + 1;
    }
    return %arguments;
}

sub mouse_down {
    my ( $self, $button ) = @_;
    return {
        type        => 'pointerDown',
        pointerType => 'mouse',
        button      => ( $button || 0 )
    };
}

sub mouse_up {
    my ( $self, $button ) = @_;
    return {
        type        => 'pointerUp',
        pointerType => 'mouse',
        button      => ( $button || 0 )
    };
}

sub perform {
    my ( $self, @actions ) = @_;
    my $message_id = $self->_new_message_id();
    my $previous_type;
    my @action_sequence;
    foreach my $parameter_action (@actions) {
        my $marionette_action = {};
        foreach my $key ( sort { $a cmp $b } keys %{$parameter_action} ) {
            $marionette_action->{$key} = $parameter_action->{$key};
        }
        my $type;
        my %type_map = (
            keyUp   => 'key',
            keyDown => 'key',
            scroll  => 'wheel',
        );
        my %arguments;
        if (   ( $marionette_action->{type} eq 'keyUp' )
            || ( $marionette_action->{type} eq 'keyDown' )
            || ( $marionette_action->{type} eq 'scroll' ) )
        {
            $type = $type_map{ $marionette_action->{type} };
        }
        elsif (( $marionette_action->{type} eq 'pointerMove' )
            || ( $marionette_action->{type} eq 'pointerDown' )
            || ( $marionette_action->{type} eq 'pointerUp' ) )
        {
            $type = 'pointer';
            %arguments =
              ( parameters =>
                  { pointerType => delete $marionette_action->{pointerType} } );
        }
        elsif ( $marionette_action->{type} eq 'pause' ) {
            if ( defined $previous_type ) {
                $type = $previous_type;
            }
            else {
                $type = 'none';
            }
        }
        else {
            Firefox::Marionette::Exception->throw(
'Unknown action type in sequence.  keyUp, keyDown, pointerMove, pointerDown, pointerUp, pause and wheel are the only known types'
            );
        }
        $self->{next_action_sequence_id}++;
        my $id = $self->{next_action_sequence_id};
        if ( ( defined $previous_type ) && ( $type eq $previous_type ) ) {
            push @{ $action_sequence[-1]{actions} }, $marionette_action;
        }
        else {
            push @action_sequence,
              {
                type => $type,
                id   => 'seq' . $id,
                %arguments, actions => [$marionette_action]
              };
        }
        $previous_type = $type;
    }
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:PerformActions'),
            { actions => \@action_sequence },

        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub release {
    my ( $self, @actions ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id, $self->_command('WebDriver:ReleaseActions')
        ]
    );
    my $response = $self->_get_response($message_id);
    $self->{next_action_sequence_id} = 0;
    return $self;
}

sub chrome_window_handles {
    my ( $self, $element ) = @_;
    if (
        $self->_is_firefox_major_version_at_least(
            _MIN_VERSION_NO_CHROME_CALLS()
        )
      )
    {
        Carp::carp(
'**** DEPRECATED METHOD - using chrome_window_handles() HAS BEEN REPLACED BY window_handles() wrapped with appropriate context() calls ****'
        );
        my $old      = $self->context('chrome');
        my @response = $self->window_handles();
        $self->context($old);
        return @response;
    }
    else {
        my $message_id = $self->_new_message_id();
        $self->_send_request(
            [
                _COMMAND(), $message_id,
                $self->_command('WebDriver:GetChromeWindowHandles')
            ]
        );
        my $response = $self->_get_response($message_id);
        if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() )
        {
            return map {
                Firefox::Marionette::WebWindow->new( $self,
                    Firefox::Marionette::WebWindow::IDENTIFIER(), $_ )
            } @{ $response->result() };
        }
        else {
            return map {
                Firefox::Marionette::WebWindow->new( $self,
                    Firefox::Marionette::WebWindow::IDENTIFIER(), $_ )
            } @{ $response->result()->{value} };
        }
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
    return Firefox::Marionette::WebWindow->new( $self,
        Firefox::Marionette::WebWindow::IDENTIFIER() =>
          $self->_response_result_value($response) );
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
        return map {
            Firefox::Marionette::WebWindow->new( $self,
                Firefox::Marionette::WebWindow::IDENTIFIER(), $_ )
        } @{ $response->result() };
    }
    else {
        return map {
            Firefox::Marionette::WebWindow->new( $self,
                Firefox::Marionette::WebWindow::IDENTIFIER(), $_ )
        } @{ $response->result()->{value} };
    }
}

sub new_window {
    my ( $self, %parameters ) = @_;

    foreach my $key (qw(focus private)) {
        if ( defined $parameters{$key} ) {
            $parameters{$key} =
              $self->_translate_to_json_boolean( $parameters{$key} );
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
    return Firefox::Marionette::WebWindow->new( $self,
        Firefox::Marionette::WebWindow::IDENTIFIER() =>
          $response->result()->{handle} );
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
        return (
            Firefox::Marionette::WebWindow->new(
                $self,
                Firefox::Marionette::WebWindow::IDENTIFIER() =>
                  $self->_response_result_value($response)
            )
        );
    }
    else {
        return map {
            Firefox::Marionette::WebWindow->new( $self,
                Firefox::Marionette::WebWindow::IDENTIFIER() => $_ )
        } @{ $response->result() };
    }
}

sub close_current_window_handle {
    my ($self) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command('WebDriver:CloseWindow') ] );
    my $response = $self->_get_response($message_id);
    if ( ref $response->result() eq 'HASH' ) {
        return (
            Firefox::Marionette::WebWindow->new(
                $self,
                Firefox::Marionette::WebWindow::IDENTIFIER() =>
                  $response->result()
            )
        );
    }
    else {
        return map {
            Firefox::Marionette::WebWindow->new( $self,
                Firefox::Marionette::WebWindow::IDENTIFIER() => $_ )
        } @{ $response->result() };
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

sub has {
    my ( $self, $value, $using, $from ) = @_;
    return $self->_find( $value, $using, $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_id {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'id', $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_name {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'name', $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_tag {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'tag name', $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_class {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'class name', $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_selector {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'css selector', $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_link {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'link text', $from,
        { return_undef_if_no_such_element => 1 } );
}

sub has_partial {
    my ( $self, $value, $from ) = @_;
    return $self->_find( $value, 'partial link text',
        $from, { return_undef_if_no_such_element => 1 } );
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

sub _determine_from {
    my ( $self, $from ) = @_;
    my $parameters = {};
    if ( defined $from ) {
        if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() )
        {
            if (   ( defined $from )
                && ( ref $from eq 'Firefox::Marionette::ShadowRoot' ) )
            {
                $parameters->{shadowRoot} = $from->uuid();
            }
            else {
                $parameters->{element} = $from->uuid();
            }
        }
        else {
            $parameters->{ELEMENT} = $from->uuid();
        }
    }
    return %{$parameters};
}

sub _retry_find_response {
    my ( $self, $command, $parameters, $options ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command($command), $parameters ] );
    return $self->_get_response( $message_id,
        { using => $parameters->{using}, value => $parameters->{value} },
        $options );
}

sub _get_and_retry_find_response {
    my ( $self, $value, $using, $from, $options ) = @_;
    my $want_array = delete $options->{want_array};
    my $message_id = $self->_new_message_id();
    my $parameters =
      { using => $using, value => $value, $self->_determine_from($from) };
    my $command =
      $want_array ? 'WebDriver:FindElements' : 'WebDriver:FindElement';
    if ( $parameters->{shadowRoot} ) {
        $command .= 'FromShadowRoot';
    }
    $self->_send_request(
        [ _COMMAND(), $message_id, $self->_command($command), $parameters, ] );
    my $response;
    eval {
        $response = $self->_get_response( $message_id,
            { using => $using, value => $value }, $options );
    } or do {
        my $quoted_using = quotemeta $using;
        my $quoted_value = quotemeta $value;
        my $invalid_selector_re =
            qr/invalid[ ]selector:[ ]/smx
          . qr/Given[ ](?:$quoted_using)[ ]expression[ ]/smx
          . qr/["](?:$quoted_value)["][ ]is[ ]invalid:[ ]/smx;
        my $type_error_tag_re = qr/TypeError:[ ]/smx
          . qr/startNode[.]getElementsByTagName[ ]is[ ]not[ ]a[ ]function/smx;
        my $not_supported_re =
          qr/NotSupportedError:[ ]Operation[ ]is[ ]not[ ]supported/smx;
        my $type_error_class_re = qr/TypeError:[ ]/smx
          . qr/startNode[.]getElementsByClassName[ ]is[ ]not[ ]a[ ]function/smx;
        if ( $EVAL_ERROR =~ /^$invalid_selector_re$type_error_tag_re/smx ) {
            $parameters->{using} = 'css selector';
            $response =
              $self->_retry_find_response( $command, $parameters, $options );
        }
        elsif ( $EVAL_ERROR =~ /^$invalid_selector_re$not_supported_re/smx ) {
            $parameters->{using} = 'css selector';
            $parameters->{value} = q{[name="} . $parameters->{value} . q["];
            $response =
              $self->_retry_find_response( $command, $parameters, $options );
        }
        elsif ( $EVAL_ERROR =~ /^$invalid_selector_re$type_error_class_re/smx )
        {
            $parameters->{using} = 'css selector';
            $parameters->{value} = q[.] . $parameters->{value};
            $response =
              $self->_retry_find_response( $command, $parameters, $options );
        }
        else {
            Carp::croak($EVAL_ERROR);
        }
    };
    return $response;
}

sub _find {
    my ( $self, $value, $using, $from, $options ) = @_;
    $using ||= 'xpath';
    $options->{want_array} = wantarray;
    my $response =
      $self->_get_and_retry_find_response( $value, $using, $from, $options );
    if (wantarray) {
        if ( $response->ignored_exception() ) {
            return ();
        }
        if ( $self->marionette_protocol() == _MARIONETTE_PROTOCOL_VERSION_3() )
        {
            return
              map { Firefox::Marionette::Element->new( $self, %{$_} ) }
              @{ $response->result() };
        }
        elsif (
               ( ref $self->_response_result_value($response) )
            && ( ( ref $self->_response_result_value($response) ) eq 'ARRAY' )
            && ( ref $self->_response_result_value($response)->[0] )
            && ( ( ref $self->_response_result_value($response)->[0] ) eq
                'HASH' )
          )
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
        if ( $response->ignored_exception() ) {
            return;
        }
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
        eval {
            if ( $self->_session_id() ) {
                $self->_quit_over_marionette($flags);
                delete $self->{session_id};
            }
            $self->_terminate_xvfb();
            1;
        } or do {
            warn "Caught an exception while quitting:$EVAL_ERROR\n";
        };
        eval {
            if ( $self->_ssh() ) {
                $self->_cleanup_remote_filesystem();
                $self->_terminate_master_control_via_ssh();
            }
            $self->_cleanup_local_filesystem();
            delete $self->{creation_pid};
        } or do {
            warn "Caught an exception while cleaning up:$EVAL_ERROR\n";
        };
        $self->_terminate_process();
    }
    else {
        $self->_terminate_process();
    }
    if ( !$self->_reconnected() ) {
        if ( $self->ssh_local_directory() ) {
            File::Path::rmtree( $self->ssh_local_directory(), 0, 0 );
        }
        elsif ( defined $self->root_directory() ) {
            File::Path::rmtree( $self->root_directory(), 0, 0 );
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
            $self->_wait_for_firefox_to_exit();
        }
        if ( defined $self->{_win32_firefox_process} ) {
            $self->{_win32_firefox_process}->Wait( Win32::Process::INFINITE() );
            $self->_wait_for_firefox_to_exit();
        }
    }
    elsif ( ( $OSNAME eq 'MSWin32' ) && ( !$self->_ssh() ) ) {
        $self->{_win32_firefox_process}->Wait( Win32::Process::INFINITE() );
        $self->_wait_for_firefox_to_exit();
    }
    else {
        if ( !close $socket ) {
            my $error = $EXTENDED_OS_ERROR;
            $self->_terminate_xvfb();
            Firefox::Marionette::Exception->throw(
                "Failed to close socket to firefox:$error");
        }
        $socket = undef;
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
        if ( !$self->_reconnected() ) {
            while ( kill 0, $self->_local_ssh_pid() ) {
                sleep 1;
                $self->_reap();
            }
        }
        if ( $self->_firefox_pid() ) {
            while ( $self->_remote_process_running( $self->_firefox_pid() ) ) {
                sleep 1;
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

sub uname {
    my ($self) = @_;
    if ( my $ssh = $self->_ssh() ) {
        return $self->_remote_uname();
    }
    else {
        return $OSNAME;
    }
}

sub _get_remote_environment_command {
    my ( $self, $name ) = @_;
    my $command;
    if ( ( $self->_remote_uname() ) && ( $self->_remote_uname() eq 'MSWin32' ) )
    {
        $command = q[echo ] . $name . q[="%] . $name . q[%"];
    }
    elsif (( $self->_remote_uname() )
        && ( $self->_remote_uname() =~ /^(?:freebsd|dragonfly)$/smx ) )
    {
        $command = 'echo ' . $name . q[=] . q[\\"] . q[$] . $name . q[\\"];
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
    my $parameters = { ignore_exit_status => 1 };
    if ( $name eq 'DISPLAY' ) {
        $parameters->{graphical} = 1;
    }
    my $output = $self->_execute_via_ssh( $parameters,
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
                    {},
                    'ssh',
                    $self->_ssh_arguments(),
                    $self->_ssh_address(),
                    (
                        join q[ ], 'if',
                        'exist',   $remote_directory,
                        $binary,   @parameters,
                        $remote_directory
                    )
                );
            }
        }
        else {
            $self->_system( {}, 'ssh', $self->_ssh_arguments(),
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
    $self->_system( {}, 'ssh', $self->_ssh_arguments(),
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

sub _terminate_marionette_process {
    my ($self) = @_;
    if ( $self->_adb() ) {
        $self->execute(
            q[adb], qw(-s), $self->_adb_serial(),
            qw(shell am force-stop),
            $self->_adb_package_name()
        );
    }
    else {
        if ( $OSNAME eq 'MSWin32' ) {
            $self->_terminate_local_win32_process();
        }
        elsif ( my $ssh = $self->_ssh() ) {
            $self->_terminate_process_via_ssh();
        }
        elsif ( ( $self->_firefox_pid() ) && ( kill 0, $self->_firefox_pid() ) )
        {
            $self->_terminate_local_non_win32_process();
        }
    }
    return;
}

sub _terminate_process {
    my ($self) = @_;
    $self->_terminate_marionette_process();
    $self->_terminate_xvfb();
    return;
}

sub _terminate_xvfb {
    my ($self) = @_;
    if ( my $pid = $self->xvfb_pid() ) {
        my $int_signal = $self->_signal_number('INT');
        while ( kill 0, $pid ) {
            kill $int_signal, $pid;
            sleep 1;
            $self->_reap();
        }
    }
    return;
}

sub content {
    my ($self) = @_;
    $self->_context('content');
    return $self;
}

sub chrome {
    my ($self) = @_;
    $self->_context('chrome');
    return $self;
}

sub context {
    my ( $self, $new ) = @_;
    return $self->_context($new);
}

sub _context {
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
            { value => $self->_translate_to_json_boolean($new) }
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self;
}

sub async_script {
    my ( $self, $script, %parameters ) = @_;
    %parameters = $self->_script_parameters( %parameters, script => $script );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:ExecuteAsyncScript'), {%parameters}
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
    my $script = delete $parameters{script};
    if ( !$self->_is_script_missing_args_okay() ) {
        $parameters{args} ||= [];
    }
    if ( ( $parameters{args} ) && ( ref $parameters{args} ne 'ARRAY' ) ) {
        $parameters{args} = [ $parameters{args} ];
    }
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
            $parameters{$key} =
              $self->_translate_to_json_boolean( $parameters{$key} );
        }
    }
    $parameters{script} = $script;
    if ( $self->_is_script_script_parameter_okay() ) {
    }
    else {
        $parameters{value} = $parameters{script};
    }
    return %parameters;
}

sub script {
    my ( $self, $script, %parameters ) = @_;
    %parameters = $self->_script_parameters( %parameters, script => $script );
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:ExecuteScript'), {%parameters}
        ]
    );
    my $response = $self->_get_response($message_id);
    return $self->_check_for_and_translate_into_objects(
        $self->_response_result_value($response) );
}

sub _get_any_class_from_variable {
    my ( $self, $object ) = @_;
    my $class;
    my $old_class;
    my $count = 0;
    foreach my $key ( sort { $a cmp $b } keys %{$object} ) {
        foreach my $known_class (
            qw(
            Firefox::Marionette::Element
            Firefox::Marionette::ShadowRoot
            Firefox::Marionette::WebFrame
            Firefox::Marionette::WebWindow
            )
          )
        {
            if ( $key eq $known_class->IDENTIFIER() ) {
                $class = $known_class;
            }
        }
        if ( $key eq 'ELEMENT' ) {
            $old_class = 'Firefox::Marionette::Element';
        }
        $count += 1;
    }
    if ( ( $count == 1 ) && ( defined $class ) ) {
        return $class;
    }
    elsif ( !$self->_is_using_webdriver_ids_exclusively() ) {
        if ( ( $count == 1 ) && ( defined $old_class ) ) {
            return $old_class;
        }
        elsif (( $count == 2 )
            && ( defined $class ) )
        {
            return $class;
        }
        else {
            foreach my $key ( sort { $a cmp $b } keys %{$object} ) {
                $object->{$key} = $self->_check_for_and_translate_into_objects(
                    $object->{$key} );
            }
        }
    }
    else {
        foreach my $key ( sort { $a cmp $b } keys %{$object} ) {
            $object->{$key} =
              $self->_check_for_and_translate_into_objects( $object->{$key} );
        }
    }
    return;
}

sub _check_for_and_translate_into_objects {
    my ( $self, $value ) = @_;
    if ( my $ref = ref $value ) {
        if ( $ref eq 'HASH' ) {
            if ( my $class = $self->_get_any_class_from_variable($value) ) {
                my $instance = $class->new( $self, %{$value} );
                return $instance;
            }
        }
        elsif ( $ref eq 'ARRAY' ) {
            my @objects;
            foreach my $object ( @{$value} ) {
                push @objects,
                  $self->_check_for_and_translate_into_objects($object);
            }
            return \@objects;
        }
    }
    return $value;
}

sub json {
    my ( $self, $uri ) = @_;
    if ( defined $uri ) {
        my $old  = $self->_context('chrome');
        my $json = $self->script(
            $self->_compress_script( <<'_SCRIPT_'), args => [$uri] );
return (async function(url) {
  let response = await fetch(url, { method: "GET", mode: "cors", headers: { "Content-Type": "application/json" }, redirect: "follow", referrerPolicy: "no-referrer"});
  if (response.ok) {
	  return await response.json();
  } else {
	  throw new Error(url + " returned a " + response.status);
  }
})(arguments[0]);
_SCRIPT_
        $self->_context($old);
        return $json;
    }
    else {

        my $content = $self->strip();
        my $json    = JSON->new()->decode($content);
        return $json;
    }
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

sub shadowy {
    my ( $self, $element ) = @_;
    if (
        $self->script(
q[if (arguments[0].shadowRoot) { return true } else { return false }],
            args => [$element]
        )
      )
    {
        return 1;
    }
    else {
        return 0;
    }
}

sub shadow_root {
    my ( $self, $element ) = @_;
    my $message_id = $self->_new_message_id();
    $self->_send_request(
        [
            _COMMAND(), $message_id,
            $self->_command('WebDriver:GetShadowRoot'),
            { id => $element->uuid() }
        ]
    );
    my $response = $self->_get_response($message_id);
    return Firefox::Marionette::ShadowRoot->new( $self,
        %{ $self->_response_result_value($response) } );
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
                (
                    $self->_is_modern_switch_window_okay()
                    ? ()
                    : (
                        value => "$window_handle",
                        name  => "$window_handle",
                    )
                ),
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
                url => "$uri",
                ( $self->_is_modern_go_okay() ? () : ( value => "$uri" ) ),
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
    while ($found) {
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
    if ( $self->{developer_edition} ) {
        return 1;
    }
    elsif (( defined $self->{_initial_version} )
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
        elsif ( FileHandle->new( $path, Fcntl::O_RDONLY() ) ) {
            ( $volume, $directories, $name ) = File::Spec->splitpath($path);
            $base_directory = File::Spec->catdir( $volume, $directories );
            if ( $OSNAME eq 'cygwin' ) {
                $base_directory =~
                  s/^\/\//\//smx;   # seems to be a bug in File::Spec for cygwin
            }
        }
        else {
            Firefox::Marionette::Exception->throw(
                "Failed to find extension $path:$EXTENDED_OS_ERROR");
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
            "Failed to open '$xpi_path' for reading:$EXTENDED_OS_ERROR");
        binmode $handle;
        my $addons_directory = $self->{_addons_directory};
        $actual_path = $self->_remote_catfile( $addons_directory, $name );
        $self->_put_file_via_scp( $handle, $actual_path, 'addon ' . $name );
        if ( $self->_remote_uname() eq 'cygwin' ) {
            $addons_directory =
              $self->_execute_via_ssh( {}, 'cygpath', '-s', '-w',
                $addons_directory );
            chomp $addons_directory;
            $actual_path =
              File::Spec::Win32->catdir( $addons_directory, $name );
        }
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
                temporary => $self->_translate_to_json_boolean($temporary),
            }
        ]
    );
    my $response = $self->_get_response($message_id);
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
    my $encoder = JSON->new()->convert_blessed()->ascii();
    if ( $self->debug() ) {
        $encoder->canonical(1);
    }
    my $json   = $encoder->encode($object);
    my $length = length $json;
    if ( $self->debug() ) {
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

sub _handle_socket_read_failure {
    my ($self) = @_;
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
    return;
}

sub _read_from_socket {
    my ($self) = @_;
    my $number_of_bytes_in_response;
    my $initial_buffer;
    while ( ( !defined $number_of_bytes_in_response ) && ( $self->alive() ) ) {
        my $number_of_bytes;
        my $octet;
        if ( $self->{_initial_octet_read_from_marionette_socket} ) {
            $octet = delete $self->{_initial_octet_read_from_marionette_socket};
            $number_of_bytes = length $octet;
        }
        else {
            $number_of_bytes = sysread $self->_socket(), $octet, 1;
        }
        if ( defined $number_of_bytes ) {
            $initial_buffer .= $octet;
        }
        else {
            $self->_handle_socket_read_failure();
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
    if ( ( $self->debug() ) && ( defined $number_of_bytes_in_response ) ) {
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
    my ( $self, $message_id, $parameters, $options ) = @_;
    my $next_message = $self->_read_from_socket();
    my $response =
      Firefox::Marionette::Response->new( $next_message, $parameters,
        $options );
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
        }
    }
    return;
}

sub _cleanup_local_filesystem {
    my ($self) = @_;
    if ( $self->ssh_local_directory() ) {
        File::Path::rmtree( $self->ssh_local_directory(), 0, 0 );
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
    return;
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette - Automate the Firefox browser with the Marionette protocol

=head1 VERSION

Version 1.51

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    say $firefox->find_tag('title')->property('innerHTML'); # same as $firefox->title();

    say $firefox->html();

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    say "Height of page-content div is " . $firefox->find_class('page-content')->css('height');

    my $file_handle = $firefox->selfie();

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

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

=head2 add_bookmark

accepts a L<bookmark|Firefox::Marionette::Bookmark> as a parameter and adds the specified bookmark to the Firefox places database.

    use Firefox::Marionette();

    my $bookmark = Firefox::Marionette::Bookmark->new(
                     url   => 'https://metacpan.org',
                     title => 'This is MetaCPAN!'
                             );
    my $firefox = Firefox::Marionette->new()->add_bookmark($bookmark);

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 add_certificate

accepts a hash as a parameter and adds the specified certificate to the Firefox database with the supplied or default trust.  Allowed keys are below;

=over 4

=item * path - a file system path to a single L<PEM encoded X.509 certificate|https://datatracker.ietf.org/doc/html/rfc7468#section-5>.

=item * string - a string containing a single L<PEM encoded X.509 certificate|https://datatracker.ietf.org/doc/html/rfc7468#section-5>

=item * trust - This is the L<trustargs|https://www.mankier.com/1/certutil#-t> value for L<NSS|https://wiki.mozilla.org/NSS>.  If defaults to 'C,,';

=back

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();

    my $pem_encoded_string = <<'_PEM_';
    -----BEGIN CERTIFICATE-----
    MII..
    -----END CERTIFICATE-----
    _PEM_
    my $firefox = Firefox::Marionette->new()->add_certificate(string => $pem_encoded_string);

=head2 add_cookie

accepts a single L<cookie|Firefox::Marionette::Cookie> object as the first parameter and adds it to the current cookie jar.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

This method throws an exception if you try to L<add a cookie for a different domain than the current document|https://developer.mozilla.org/en-US/docs/Web/WebDriver/Errors/InvalidCookieDomain>.

=head2 add_header

accepts a hash of HTTP headers to include in every future HTTP Request.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();
    my $uuid = UUID::uuid();
    $firefox->add_header( 'Track-my-automated-tests' => $uuid );
    $firefox->go('https://metacpan.org/');

these headers are added to any existing headers.  To clear headers, see the L<delete_header|/delete_header> method

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->delete_header( 'Accept' )->add_header( 'Accept' => 'text/perl' )->go('https://metacpan.org/');

will only send out an L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> header that looks like C<Accept: text/perl>.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->add_header( 'Accept' => 'text/perl' )->go('https://metacpan.org/');

by itself, will send out an L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> header that may resemble C<Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8, text/perl>. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 add_login

accepts a hash of the following keys;

=over 4

=item * host - The scheme + hostname of the page where the login applies, for example 'https://www.example.org'.

=item * user - The username for the login.

=item * password - The password for the login.

=item * origin - The scheme + hostname that the form-based login L<was submitted to|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action>.  Forms with no L<action attribute|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action> default to submitting to the URL of the page containing the login form, so that is stored here. This field should be omitted (it will be set to undef) for http auth type authentications and "" means to match against any form action.

=item * realm - The HTTP Realm for which the login was requested. When an HTTP server sends a 401 result, the WWW-Authenticate header includes a realm. See L<RFC 2617|https://datatracker.ietf.org/doc/html/rfc2617>.  If the realm is not specified, or it was blank, the hostname is used instead. For HTML form logins, this field should not be specified.

=item * user_field - The name attribute for the username input in a form. Non-form logins should not specify this field.

=item * password_field - The name attribute for the password input in a form. Non-form logins should not specify this field.

=back

or a L<Firefox::Marionette::Login|Firefox::Marionette::Login> object as the first parameter and adds the login to the Firefox login database.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();

    # for http auth logins

    my $http_auth_login = Firefox::Marionette::Login->new(host => 'https://pause.perl.org', user => 'AUSER', password => 'qwerty', realm => 'PAUSE');
    $firefox->add_login($http_auth_login);
    $firefox->go('https://pause.perl.org/pause/authenquery')->accept_alert(); # this goes to the page and submits the http auth popup

    # for form based login

    my $form_login = Firefox::Marionette::Login(host => 'https://github.com', user => 'me2@example.org', password => 'uiop[]', user_field => 'login', password_field => 'password');
    $firefox->add_login($form_login);

    # or just directly

    $firefox->add_login(host => 'https://github.com', user => 'me2@example.org', password => 'uiop[]', user_field => 'login', password_field => 'password');

Note for HTTP Authentication, the L<realm|https://datatracker.ietf.org/doc/html/rfc2617#section-2> must perfectly match the correct L<realm|https://datatracker.ietf.org/doc/html/rfc2617#section-2> supplied by the server.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 add_site_header

accepts a host name and a hash of HTTP headers to include in every future HTTP Request that is being sent to that particular host.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();
    my $uuid = UUID::uuid();
    $firefox->add_site_header( 'metacpan.org', 'Track-my-automated-tests' => $uuid );
    $firefox->go('https://metacpan.org/');

these headers are added to any existing headers going to the metacpan.org site, but no other site.  To clear site headers, see the L<delete_site_header|/delete_site_header> method

=head2 add_webauthn_authenticator

accepts a hash of the following keys;

=over 4

=item * has_resident_key - boolean value to indicate if the authenticator will support L<client side discoverable credentials|https://www.w3.org/TR/webauthn-2/#client-side-discoverable-credential>

=item * has_user_verification - boolean value to determine if the L<authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators> supports L<user verification|https://www.w3.org/TR/webauthn-2/#user-verification>.

=item * is_user_consenting - boolean value to determine the result of all L<user consent|https://www.w3.org/TR/webauthn-2/#user-consent> L<authorization gestures|https://www.w3.org/TR/webauthn-2/#authorization-gesture>, and by extension, any L<test of user presence|https://www.w3.org/TR/webauthn-2/#test-of-user-presence> performed on the L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators>. If set to true, a L<user consent|https://www.w3.org/TR/webauthn-2/#user-consent> will always be granted. If set to false, it will not be granted.

=item * is_user_verified - boolean value to determine the result of L<User Verification|https://www.w3.org/TR/webauthn-2/#user-verification> performed on the L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators>. If set to true, L<User Verification|https://www.w3.org/TR/webauthn-2/#user-verification> will always succeed. If set to false, it will fail.

=item * protocol - the L<protocol|Firefox::Marionette::WebAuthn::Authenticator#protocol> spoken by the authenticator.  This may be L<CTAP1_U2F|Firefox::Marionette::WebAuthn::Authenticator#CTAP1_U2F>, L<CTAP2|Firefox::Marionette::WebAuthn::Authenticator#CTAP2> or L<CTAP2_1|Firefox::Marionette::WebAuthn::Authenticator#CTAP2_1>.

=item * transport - the L<transport|Firefox::Marionette::WebAuthn::Authenticator#transport> simulated by the authenticator.  This may be L<BLE|Firefox::Marionette::WebAuthn::Authenticator#BLE>, L<HYBRID|Firefox::Marionette::WebAuthn::Authenticator#HYBRID>, L<INTERNAL|Firefox::Marionette::WebAuthn::Authenticator#INTERNAL>, L<NFC|Firefox::Marionette::WebAuthn::Authenticator#NFC>, L<SMART_CARD|Firefox::Marionette::WebAuthn::Authenticator#SMART_CARD> or L<USB|Firefox::Marionette::WebAuthn::Authenticator#USB>.

=back

It returns the newly created L<authenticator|Firefox::Marionette::WebAuthn::Authenticator>.

    use Firefox::Marionette();
    use Crypt::URandom();

    my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
    my $firefox = Firefox::Marionette->new( webauthn => 0 );
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('register-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });

=head2 add_webauthn_credential

accepts a hash of the following keys;

=over 4

=item * authenticator - contains the L<authenticator|Firefox::Marionette::WebAuthn::Authenticator> that the credential will be added to.  If this parameter is not supplied, the credential will be added to the default authenticator, if one exists.

=item * host - contains the domain that this credential is to be used for.  In the language of L<WebAuthn|https://www.w3.org/TR/webauthn-2>, this field is referred to as the L<relying party identifier|https://www.w3.org/TR/webauthn-2/#relying-party-identifier> or L<RP ID|https://www.w3.org/TR/webauthn-2/#rp-id>.

=item * id - contains the unique id for this credential, also known as the L<Credential ID|https://www.w3.org/TR/webauthn-2/#credential-id>.  If this is not supplied, one will be generated.

=item * is_resident - contains a boolean that if set to true, a L<client-side discoverable credential|https://w3c.github.io/webauthn/#client-side-discoverable-credential> is created. If set to false, a L<server-side credential|https://w3c.github.io/webauthn/#server-side-credential> is created instead.

=item * private_key - either a L<RFC5958|https://www.rfc-editor.org/rfc/rfc5958> encoded private key encoded using L<encode_base64url|MIME::Base64::encode_base64url> or a hash containing the following keys;

=over 8

=item * name - contains the name of the private key algorithm, such as "RSA-PSS" (the default), "RSASSA-PKCS1-v1_5", "ECDSA" or "ECDH".

=item * size - contains the modulus length of the private key.  This is only valid for "RSA-PSS" or "RSASSA-PKCS1-v1_5" private keys.

=item * hash - contains the name of the hash algorithm, such as "SHA-512" (the default).  This is only valid for "RSA-PSS" or "RSASSA-PKCS1-v1_5" private keys.

=item * curve - contains the name of the curve for the private key, such as "P-384" (the default).  This is only valid for "ECDSA" or "ECDH" private keys.

=back

=item * sign_count - contains the initial value for a L<signature counter|https://w3c.github.io/webauthn/#signature-counter> associated to the L<public key credential source|https://w3c.github.io/webauthn/#public-key-credential-source>.  It will default to 0 (zero).

=item * user - contains the L<userHandle|https://w3c.github.io/webauthn/#public-key-credential-source-userhandle> associated to the credential encoded using L<encode_base64url|MIME::Base64::encode_base64url>.  This property is optional.

=back

It returns the newly created L<credential|Firefox::Marionette::WebAuthn::Credential>.  If of course, the credential is just created, it probably won't be much good by itself.  However, you can use it to recreate a credential, so long as you know all the parameters.

    use Firefox::Marionette();
    use Crypt::URandom();

    my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
    my $firefox = Firefox::Marionette->new();
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('register-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });
    foreach my $credential ($firefox->webauthn_credentials()) {
        $firefox->delete_webauthn_credential($credential);

# ... time passes ...

        $firefox->add_webauthn_credential(
                  id            => $credential->id(),
                  host          => $credential->host(),
                  user          => $credential->user(),
                  private_key   => $credential->private_key(),
                  is_resident   => $credential->is_resident(),
                  sign_count    => $credential->sign_count(),
                              );
    }
    $firefox->go('about:blank');
    $firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_COOKIES());
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });

=head2 addons

returns if pre-existing addons (extensions/themes) are allowed to run.  This will be true for Firefox versions less than 55, as L<-safe-mode|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29> cannot be automated.

=head2 agent

accepts an optional value for the L<User-Agent|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent> header and sets this using the profile preferences.  This value will be used on the next page load.  It returns the current value, such as 'Mozilla/5.0 (<system-information>) <platform> (<platform-details>) <extensions>'.  This value is retrieved with L<navigator.userAgent|https://developer.mozilla.org/en-US/docs/Web/API/Navigator/userAgent>.

This method can be used to set a user agent string like so;

    use Firefox::Marionette();
    use strict;

    # useragents.me should only be queried once a month or less.
    # these UA strings should be cached locally.

    my %user_agent_strings = map { $_->{ua} => $_->{pct} } @{$firefox->json("https://www.useragents.me/api")->{data}};
    my ($user_agent) = reverse sort { $user_agent_strings{$a} <=> $user_agent_strings{$b} } keys %user_agent_strings;

    my $firefox = Firefox::Marionette->new();
    $firefox->agent($user_agent); # agent is now the most popular agent from useragents.me

=head2 alert_text

Returns the message shown in a currently displayed modal message box

=head2 alive

This method returns true or false depending on if the Firefox process is still running.

=head2 application_type

returns the application type for the Marionette protocol.  Should be 'gecko'.

=head2 aria_label

accepts an L<element|Firefox::Marionette::Element> as the parameter.  It returns the L<ARIA label|https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-label> for the L<element|Firefox::Marionette::Element>.

=head2 aria_role

accepts an L<element|Firefox::Marionette::Element> as the parameter.  It returns the L<ARIA role|https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles> for the L<element|Firefox::Marionette::Element>.

=head2 async_script 

accepts a scalar containing a javascript function that is executed in the browser.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

The executing javascript is subject to the L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.

=head2 attribute 

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a scalar attribute name as the second parameter.  It returns the initial value of the attribute with the supplied name.  This method will return the initial content from the HTML source code, the L<property|/property> method will return the current content.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_id('metacpan_search-input');
    !defined $element->attribute('value') or die "attribute is defined but did not exist in the html source!";
    $element->type('Test::More');
    !defined $element->attribute('value') or die "attribute has changed but only the property should have changed!";

=head2 await

accepts a subroutine reference as a parameter and then executes the subroutine.  If a L<not found|Firefox::Marionette::Exception::NotFound> exception is thrown, this method will sleep for L<sleep_time_in_ms|/sleep_time_in_ms> milliseconds and then execute the subroutine again.  When the subroutine executes successfully, it will return what the subroutine returns.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(sleep_time_in_ms => 5)->go('https://metacpan.org/');

    $firefox->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

=head2 back

causes the browser to traverse one step backward in the joint history of the current browsing context.  The browser will wait for the one step backward to complete or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 debug

accept a boolean and return the current value of the debug setting.  This allows the dynamic setting of debug.

=head2 default_binary_name

just returns the string 'firefox'.  Only of interest when sub-classing.

=head2 download

accepts a L<URI|URI> and an optional timeout in seconds (the default is 5 minutes) as parameters and downloads the L<URI|URI> in the background and returns a handle to the downloaded file.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    my $handle = $firefox->download('https://raw.githubusercontent.com/david-dick/firefox-marionette/master/t/data/keepassxs.csv');

    foreach my $line (<$handle>) {
      print $line;
    }

=head2 bookmarks

accepts either a scalar or a hash as a parameter.  The scalar may by the title of a bookmark or the L<URL|URI::URL> of the bookmark.  The hash may have the following keys;

=over 4

=item * title - The title of the bookmark.

=item * url - The url of the bookmark.

=back

returns a list of all L<Firefox::Marionette::Bookmark|Firefox::Marionette::Bookmark> objects that match the supplied parameters (if any).

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    foreach my $bookmark ($firefox->bookmarks(title => 'This is MetaCPAN!')) {
      say "Bookmark found";
    }

    # OR

    foreach my $bookmark ($firefox->bookmarks()) {
      say "Bookmark found with URL " . $bookmark->url();
    }

    # OR

    foreach my $bookmark ($firefox->bookmarks('https://metacpan.org')) {
      say "Bookmark found";
    }

=head2 browser_version

This method returns the current version of firefox.

=head2 bye

accepts a subroutine reference as a parameter and then executes the subroutine.  If the subroutine executes successfully, this method will sleep for L<sleep_time_in_ms|/sleep_time_in_ms> milliseconds and then execute the subroutine again.  When a L<not found|Firefox::Marionette::Exception::NotFound> exception is thrown, this method will return L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->bye(sub { $firefox->find_name('metacpan_search-input') })->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

=head2 cache_keys

returns the set of all cache keys from L<Firefox::Marionette::Cache|Firefox::Marionette::Cache>.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    foreach my $key_name ($firefox->cache_keys()) {
      my $key_value = $firefox->check_cache_key($key_name);
      if (Firefox::Marionette::Cache->$key_name() != $key_value) {
        warn "This module this the value of $key_name is " . Firefox::Marionette::Cache->$key_name();
        warn "Firefox thinks the value of   $key_name is $key_value";
      }
    }

=head2 capabilities

returns the L<capabilities|Firefox::Marionette::Capabilities> of the current firefox binary.  You can retrieve L<timeouts|Firefox::Marionette::Timeouts> or a L<proxy|Firefox::Marionette::Proxy> with this method.

=head2 certificate_as_pem

accepts a L<certificate stored in the Firefox database|Firefox::Marionette::Certificate> as a parameter and returns a L<PEM encoded X.509 certificate|https://datatracker.ietf.org/doc/html/rfc7468#section-5> as a string.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    # Generating a ca-bundle.crt to STDOUT from the current firefox instance

    foreach my $certificate (sort { $a->display_name() cmp $b->display_name } $firefox->certificates()) {
        if ($certificate->is_ca_cert()) {
            print '# ' . $certificate->display_name() . "\n" . $firefox->certificate_as_pem($certificate) . "\n";
        }
    }

The L<ca-bundle-for-firefox|ca-bundle-for-firefox> command that is provided as part of this distribution does this.

=head2 certificates

returns a list of all known L<certificates in the Firefox database|Firefox::Marionette::Certificate>.

    use Firefox::Marionette();
    use v5.10;

    # Sometimes firefox can neglect old certificates.  See https://bugzilla.mozilla.org/show_bug.cgi?id=1710716

    my $firefox = Firefox::Marionette->new();
    foreach my $certificate (grep { $_->is_ca_cert() && $_->not_valid_after() < time } $firefox->certificates()) {
        say "The " . $certificate->display_name() " . certificate has expired and should be removed";
        print 'PEM Encoded Certificate ' . "\n" . $firefox->certificate_as_pem($certificate) . "\n";
    }

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 check_cache_key

accepts a L<cache_key|Firefox::Marionette::Cache> as a parameter.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    foreach my $key_name ($firefox->cache_keys()) {
      my $key_value = $firefox->check_cache_key($key_name);
      if (Firefox::Marionette::Cache->$key_name() != $key_value) {
        warn "This module this the value of $key_name is " . Firefox::Marionette::Cache->$key_name();
        warn "Firefox thinks the value of   $key_name is $key_value";
      }
    }

This method returns the L<cache_key|Firefox::Marionette::Cache>'s actual value from firefox as a number.  This may differ from the current value of the key from L<Firefox::Marionette::Cache|Firefox::Marionette::Cache> as these values have changed as firefox has evolved.

=head2 child_error

This method returns the $? (CHILD_ERROR) for the Firefox process, or undefined if the process has not yet exited.

=head2 chrome

changes the scope of subsequent commands to chrome context.  This allows things like interacting with firefox menu's and buttons outside of the browser window.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->chrome();
    $firefox->script(...); # running script in chrome context
    $firefox->content();

See the L<context|/context> method for an alternative methods for changing the context.

=head2 chrome_window_handle

returns a L<server-assigned identifier for the current chrome window that uniquely identifies it|Firefox::Marionette::WebWindow> within this Marionette instance.  This can be used to switch to this window at a later point. This corresponds to a window that may itself contain tabs.  This method is replaced by L<window_handle|/window_handle> and appropriate L<context|/context> calls for L<Firefox 94 and after|https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/94#webdriver_conformance_marionette>.

=head2 chrome_window_handles

returns L<identifiers|Firefox::Marionette::WebWindow> for each open chrome window for tests interested in managing a set of chrome windows and tabs separately.  This method is replaced by L<window_handles|/window_handles> and appropriate L<context|/context> calls for L<Firefox 94 and after|https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/94#webdriver_conformance_marionette>.

=head2 clear

accepts a L<element|Firefox::Marionette::Element> as the first parameter and clears any user supplied input

=head2 clear_cache

accepts a single flag parameter, which can be an ORed set of keys from L<Firefox::Marionette::Cache|Firefox::Marionette::Cache> and clears the appropriate sections of the cache.  If no flags parameter is supplied, the default is L<CLEAR_ALL|Firefox::Marionette::Cache#CLEAR_ALL>.  Note that this method, unlike L<delete_cookies|/delete_cookies> will actually delete all cookies for all hosts, not just the current webpage.

    use Firefox::Marionette();
    use Firefox::Marionette::Cache qw(:all);

    my $firefox = Firefox::Marionette->new()->go('https://do.lots.of.evil/')->clear_cache(); # default clear all

    $firefox->go('https://cookies.r.us')->clear_cache(CLEAR_COOKIES());

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 clear_pref

accepts a L<preference|http://kb.mozillazine.org/About:config> name and restores it to the original value.  See the L<get_pref|/get_pref> and L<set_pref|/set_pref> methods to get a preference value and to set to it to a particular value.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();
    my $firefox = Firefox::Marionette->new();

    $firefox->clear_pref('browser.search.defaultenginename');

=head2 click

accepts a L<element|Firefox::Marionette::Element> as the first parameter and sends a 'click' to it.  The browser will wait for any page load to complete or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  The L<click|/click> method is also used to choose an option in a select dropdown.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(visible => 1)->go('https://ebay.com');
    my $select = $firefox->find_tag('select');
    foreach my $option ($select->find_tag('option')) {
        if ($option->property('value') == 58058) { # Computers/Tablets & Networking
            $option->click();
        }
    }

=head2 close_current_chrome_window_handle

closes the current chrome window (that is the entire window, not just the tabs).  It returns a list of still available L<chrome window handles|Firefox::Marionette::WebWindow>. You will need to L<switch_to_window|/switch_to_window> to use another window.

=head2 close_current_window_handle

closes the current window/tab.  It returns a list of still available L<windowE<sol>tab handles|Firefox::Marionette::WebWindow>.

=head2 content

changes the scope of subsequent commands to browsing context.  This is the default for when firefox starts and restricts commands to operating in the browser window only.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->chrome();
    $firefox->script(...); # running script in chrome context
    $firefox->content();

See the L<context|/context> method for an alternative methods for changing the context.

=head2 context

accepts a string as the first parameter, which may be either 'content' or 'chrome'.  It returns the context type that is Marionette's current target for browsing context scoped commands.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    if ($firefox->context() eq 'content') {
       say "I knew that was going to happen";
    }
    my $old_context = $firefox->context('chrome');
    $firefox->script(...); # running script in chrome context
    $firefox->context($old_context);

See the L<content|/content> and L<chrome|/chrome> methods for alternative methods for changing the context.

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

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    say $firefox->find_id('metacpan_search-input')->css('height');

=head2 current_chrome_window_handle 

see L<chrome_window_handle|/chrome_window_handle>.

=head2 delete_bookmark

accepts a L<bookmark|Firefox::Marionette::Bookmark> as a parameter and deletes the bookmark from the Firefox database.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $bookmark (reverse $firefox->bookmarks()) {
      if ($bookmark->parent_guid() ne Firefox::Marionette::Bookmark::ROOT()) {
        $firefox->delete_bookmark($bookmark);
      }
    }
    say "Bookmarks? We don't need no stinking bookmarks!";

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 delete_certificate

accepts a L<certificate stored in the Firefox database|Firefox::Marionette::Certificate> as a parameter and deletes/distrusts the certificate from the Firefox database.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $certificate ($firefox->certificates()) {
        if ($certificate->is_ca_cert()) {
            $firefox->delete_certificate($certificate);
        } else {
            say "This " . $certificate->display_name() " certificate is NOT a certificate authority, therefore it is not being deleted";
        }
    }
    say "Good luck visiting a HTTPS website!";

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

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

Here be cookie monsters! Note that this method will only delete cookies for the current site.  See L<clear_cache|/clear_cache> for an alternative.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods. 

=head2 delete_header

accepts a list of HTTP header names to delete from future HTTP Requests.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_header( 'User-Agent', 'Accept', 'Accept-Encoding' );

will remove the L<User-Agent|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent>, L<Accept|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept> and L<Accept-Encoding|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding> headers from all future requests

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 delete_login

accepts a L<login|Firefox::Marionette::Login> as a parameter.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    foreach my $login ($firefox->logins()) {
        if ($login->user() eq 'me@example.org') {
            $firefox->delete_login($login);
        }
    }

will remove the logins with the username matching 'me@example.org'.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 delete_logins

This method empties the password database.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_logins();

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

=head2 delete_webauthn_all_credentials

This method accepts an optional L<authenticator|Firefox::Marionette::WebAuthn::Authenticator>, in which case it will delete all L<credentials|Firefox::Marionette::WebAuthn::Credential> from this authenticator.  If no parameter is supplied, the default authenticator will have all credentials deleted.

    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->delete_webauthn_all_credentials($authenticator);
    $firefox->delete_webauthn_all_credentials();

=head2 delete_webauthn_authenticator

This method accepts an optional L<authenticator|Firefox::Marionette::WebAuthn::Authenticator>, in which case it will delete this authenticator from the current Firefox instance.  If no parameter is supplied, the default authenticator will be deleted.

    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->delete_webauthn_authenticator($authenticator);
    $firefox->delete_webauthn_authenticator();

=head2 delete_webauthn_credential

This method accepts either a L<credential|Firefox::Marionette::WebAuthn::Credential> and an L<authenticator|Firefox::Marionette::WebAuthn::Authenticator>, in which case it will remove the credential from the supplied authenticator or

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
        $firefox->delete_webauthn_credential($credential, $authenticator);
    }

just a L<credential|Firefox::Marionette::WebAuthn::Credential>, in which case it will remove the credential from the default authenticator.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    ...
    foreach my $credential ($firefox->webauthn_credentials()) {
        $firefox->delete_webauthn_credential($credential);
    }

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 developer

returns true if the L<current version|/browser_version> of firefox is a L<developer edition|https://www.mozilla.org/en-US/firefox/developer/> (does the minor version number end with an 'b\d+'?) version.

=head2 dismiss_alert

dismisses a currently displayed modal message box

=head2 displays

accepts an optional regex to filter against the L<usage for the display|Firefox::Marionette::Display#usage> and returns a list of all the L<known displays|https://en.wikipedia.org/wiki/List_of_common_resolutions> as a L<Firefox::Marionette::Display|Firefox::Marionette::Display>.

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    my $element = $firefox->find_id('metacpan_search-input');
    foreach my $display ($firefox->displays(qr/iphone/smxi)) {
        say 'Can Firefox resize for "' . Encode::encode('UTF-8', $display->usage(), 1) . '"?';
        if ($firefox->resize($display->width(), $display->height())) {
            say 'Now displaying with a Pixel aspect ratio of ' . $display->par();
            say 'Now displaying with a Storage aspect ratio of ' . $display->sar();
            say 'Now displaying with a Display aspect ratio of ' . $display->dar();
        } else {
            say 'Apparently NOT!';
        }
    }

=head2 downloaded

accepts a filesystem path and returns a matching filehandle.  This is trivial for locally running firefox, but sufficiently complex to justify the method for a remote firefox running over ssh.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new( host => '10.1.2.3' )->go('https://metacpan.org/');

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

    while(!$firefox->downloads()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {

        my $handle = $firefox->downloaded($path);

        # do something with downloaded file handle

    }

=head2 downloading

returns true if any files in L<downloads|/downloads> end in C<.part>

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

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

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

    while(!$firefox->downloads()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {
        say $path;
    }

=head2 error_message

This method returns a human readable error message describing how the Firefox process exited (assuming it started okay).  On Win32 platforms this information is restricted to exit code.

=head2 execute

This utility method executes a command with arguments and returns STDOUT as a chomped string.  It is a simple method only intended for the Firefox::Marionette::* modules.

=head2 fill_login

This method searches the L<Password Manager|https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins> for an appropriate login for any form on the current page.  The form must match the host, the action attribute and the user and password field names.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new();

    my $firefox = Firefox::Marionette->new();

    my $url = 'https://github.com';

    my $user = 'me@example.org';

    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the $user account when logging into $url:");

    $firefox->add_login(host => $url, user => $user, password => 'qwerty', user_field => 'login', password_field => 'password');

    $firefox->go("$url/login");

    $firefox->fill_login();

=head2 find

accepts an L<xpath expression|https://en.wikipedia.org/wiki/XPath> as the first parameter and returns the first L<element|Firefox::Marionette::Element> that matches this expression.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find('//input[@id="metacpan_search-input"]')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find('//input[@id="metacpan_search-input"]')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has|/has> method.

=head2 find_id

accepts an L<id|https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/id> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with a matching 'id' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_id('metacpan_search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_id('metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has_id|/has_id> method.

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

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has_name|/has_name> method.

=head2 find_class

accepts a L<class name|https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with a matching 'class' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_class('form-control home-metacpan_search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_class('form-control home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has_class|/has_class> method.

=head2 find_selector

accepts a L<CSS Selector|https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Selectors> as the first parameter and returns the first L<element|Firefox::Marionette::Element> that matches that selector.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_selector('input.home-metacpan_search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_selector('input.home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has_selector|/has_selector> method.

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

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown. For the same functionality that returns undef if no elements are found, see the L<has_tag|/has_tag> method.

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

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has_link|/has_link> method.

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

If no elements are found, a L<not found|Firefox::Marionette::Exception::NotFound> exception will be thrown.  For the same functionality that returns undef if no elements are found, see the L<has_partial|/has_partial> method.

=head2 forward

causes the browser to traverse one step forward in the joint history of the current browsing context. The browser will wait for the one step forward to complete or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 full_screen

full screens the firefox window. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 geo

accepts an optional L<geo location|Firefox::Marionette::GeoLocation> object or the parameters for a L<geo location|Firefox::Marionette::GeoLocation> object, turns on the L<Geolocation API|https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API> and returns the current L<value|Firefox::Marionette::GeoLocation> returned by calling the javascript L<getCurrentPosition|https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/getCurrentPosition> method.  This method is further discussed in the L<GEO LOCATION|/GEO-LOCATION> section.

NOTE: firefox will only allow L<Geolocation|https://developer.mozilla.org/en-US/docs/Web/API/Geolocation> calls to be made from L<secure contexts|https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts> and bizarrely, this does not include about:blank or similar.  Therefore, you will need to load a page before calling the L<geo|/geo> method.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( proxy => 'https://this.is.another.location:3128', geo => 1 );

    # Get geolocation for this.is.another.location (via proxy)

    $firefox->geo($firefox->json('https://freeipapi.com/api/json/'));

    # now google maps will show us in this.is.another.location

    $firefox->go('https://maps.google.com/');

    my $geo = $firefox->geo();

    warn "Apparently, we're now at " . join q[, ], $geo->latitude(), $geo->longitude();

    # OR the quicker setup (run this with perl -C)

    warn "Apparently, we're now at " . Firefox::Marionette->new( proxy => 'https://this.is.another.location:3128', geo => 'https://freeipapi.com/api/json/' )->go('https://maps.google.com/')->geo();

NOTE: currently this call sets the location to be exactly what is specified.  It doesn't change anything else relevant (yet, but it may in future), such as L<languages|/languages> or the L<timezone|https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/getTimezoneOffset>.  This function should be considered experimental.  Feedback welcome.

=head2 go

Navigates the current browsing context to the given L<URI|URI> and waits for the document to load or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->go('https://metacpan.org/'); # will only return when metacpan.org is FULLY loaded (including all images / js / css)

To make the L<go|/go> method return quicker, you need to set the L<page load strategy|Firefox::Marionette::Capabilities#page_load_strategy> L<capability|Firefox::Marionette::Capabilities> to an appropriate value, such as below;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( page_load_strategy => 'eager' ));
    $firefox->go('https://metacpan.org/'); # will return once the main document has been loaded and parsed, but BEFORE sub-resources (images/stylesheets/frames) have been loaded.

When going directly to a URL that needs to be downloaded, please see L<BUGS AND LIMITATIONS|/DOWNLOADING-USING-GO-METHOD> for a necessary workaround and the L<download|/download> method for an alternative.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 get_pref

accepts a L<preference|http://kb.mozillazine.org/About:config> name.  See the L<set_pref|/set_pref> and L<clear_pref|/clear_pref> methods to set a preference value and to restore it to it's original value.  This method returns the current value of the preference.

    use Firefox::Marionette();
    my $firefox = Firefox::Marionette->new();

    warn "Your browser's default search engine is set to " . $firefox->get_pref('browser.search.defaultenginename');

=head2 har

returns a hashref representing the L<http archive|https://en.wikipedia.org/wiki/HAR_(file_format)> of the session.  This function is subject to the L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.  It is also possible for the function to hang (until the L<script|Firefox::Marionette::Timeouts#script> timeout) if the original L<devtools|https://developer.mozilla.org/en-US/docs/Tools> window is closed.  The hashref has been designed to be accepted by the L<Archive::Har|Archive::Har> module.  This function should be considered experimental.  Feedback welcome.

    use Firefox::Marionette();
    use Archive::Har();
    use v5.10;

    my $firefox = Firefox::Marionette->new(visible => 1, debug => 1, har => 1);

    $firefox->go("http://metacpan.org/");

    $firefox->find('//input[@id="metacpan_search-input"]')->type('Test::More');
    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    my $har = Archive::Har->new();
    $har->hashref($firefox->har());

    foreach my $entry ($har->entries()) {
        say $entry->request()->url() . " spent " . $entry->timings()->connect() . " ms establishing a TCP connection";
    }

=head2 has

accepts an L<xpath expression|https://en.wikipedia.org/wiki/XPath> as the first parameter and returns the first L<element|Firefox::Marionette::Element> that matches this expression.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if (my $element = $firefox->has('//input[@id="metacpan_search-input"]')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find|/find> method.

=head2 has_id

accepts an L<id|https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/id> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with a matching 'id' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if (my $element = $firefox->has_id('metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_id|/find_id> method.

=head2 has_name

This method returns the first L<element|Firefox::Marionette::Element> with a matching 'name' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_name('q')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_name|/find_name> method.

=head2 has_class

accepts a L<class name|https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with a matching 'class' property.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_class('form-control home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_class|/find_class> method.

=head2 has_selector

accepts a L<CSS Selector|https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Selectors> as the first parameter and returns the first L<element|Firefox::Marionette::Element> that matches that selector.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_selector('input.home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_selector|/find_selector> method.

=head2 has_tag

accepts a L<tag name|https://developer.mozilla.org/en-US/docs/Web/API/Element/tagName> as the first parameter and returns the first L<element|Firefox::Marionette::Element> with this tag name.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_tag('input')) {
        # do something
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_tag|/find_tag> method.

=head2 has_link

accepts a text string as the first parameter and returns the first link L<element|Firefox::Marionette::Element> that has a matching link text.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_link('API')) {
        $element->click();
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_link|/find_link> method.

=head2 has_partial

accepts a text string as the first parameter and returns the first link L<element|Firefox::Marionette::Element> that has a partially matching link text.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->find_partial('AP')) {
        $element->click();
    }

If no elements are found, this method will return undef.  For the same functionality that throws a L<not found|Firefox::Marionette::Exception::NotFound> exception, see the L<find_partial|/find_partial> method.

=head2 html

returns the page source of the content document.  This page source can be wrapped in html that firefox provides.  See the L<json|/json> method for an alternative when dealing with response content types such as application/json and L<strip|/strip> for an alternative when dealing with other non-html content types such as text/plain.

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->go('https://metacpan.org/')->html();

=head2 import_bookmarks

accepts a filesystem path to a bookmarks file and imports all the L<bookmarks|Firefox::Marionette::Bookmark> in that file.  It can deal with backups from L<Firefox|https://support.mozilla.org/en-US/kb/export-firefox-bookmarks-to-backup-or-transfer>, L<Chrome|https://support.google.com/chrome/answer/96816?hl=en> or Edge.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->import_bookmarks('/path/to/bookmarks_file.html');

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 images

returns a list of all of the following elements;

=over 4

=item * L<img|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img>

=item * L<image inputs|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/image>

=back

as L<Firefox::Marionette::Image|Firefox::Marionette::Image> objects.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $link = $firefox->images()) {
        say "Found a image with width " . $image->width() . "px and height " . $image->height() . "px from " . $image->URL();
    }

If no elements are found, this method will return undef.

=head2 install

accepts the following as the first parameter;

=over 4

=item * path to an L<xpi file|https://developer.mozilla.org/en-US/docs/Mozilla/XPI>.

=item * path to a directory containing L<firefox extension source code|https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension>.  This directory will be packaged up as an unsigned xpi file.

=item * path to a top level file (such as L<manifest.json|https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Anatomy_of_a_WebExtension#manifest.json>) in a directory containing L<firefox extension source code|https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension>.  This directory will be packaged up as an unsigned xpi file.

=back

and an optional true/false second parameter to indicate if the xpi file should be a L<temporary extension|https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/> (just for the existence of this browser instance).  Unsigned xpi files L<may only be loaded temporarily|https://wiki.mozilla.org/Add-ons/Extension_Signing> (except for L<nightly firefox installations|https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly>).  It returns the GUID for the addon which may be used as a parameter to the L<uninstall|/uninstall> method.

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

returns true if C<document.readyState === "interactive"> or if L<loaded|/loaded> is true

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_id('metacpan_search-input')->type('Type::More');
    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();
    while(!$firefox->interactive()) {
        # redirecting to Test::More page
    }

=head2 is_displayed

accepts an L<element|Firefox::Marionette::Element> as the first parameter.  This method returns true or false depending on if the element L<is displayed|https://firefox-source-docs.mozilla.org/testing/marionette/internals/interaction.html#interaction.isElementDisplayed>.

=head2 is_enabled

accepts an L<element|Firefox::Marionette::Element> as the first parameter.  This method returns true or false depending on if the element L<is enabled|https://w3c.github.io/webdriver/#is-element-enabled>.

=head2 is_selected

accepts an L<element|Firefox::Marionette::Element> as the first parameter.  This method returns true or false depending on if the element L<is selected|https://w3c.github.io/webdriver/#dfn-is-element-selected>.  Note that this method only makes sense for L<checkbox|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/checkbox> or L<radio|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/radio> inputs or L<option|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/option> elements in a L<select|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/select> dropdown.

=head2 is_trusted

accepts an L<certificate|Firefox::Marionette::Certificate> as the first parameter.  This method returns true or false depending on if the certificate is a trusted CA certificate in the current profile.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    foreach my $certificate ($firefox->certificates()) {
        if (($certificate->is_ca_cert()) && ($firefox->is_trusted($certificate))) {
            say $certificate->display_name() . " is a trusted CA cert in the current profile";
        } 
    } 

=head2 json

returns a L<JSON|JSON> object that has been parsed from the page source of the content document.  This is a convenience method that wraps the L<strip|/strip> method.

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->go('https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette")->json()->{version};

In addition, this method can accept a L<URI|URI> as a parameter and retrieve that URI via the firefox L<fetch call|https://developer.mozilla.org/en-US/docs/Web/API/fetch> and transforming the body to L<JSON via firefox|https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static>

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->json('https://freeipapi.com/api/json/')->{ipAddress};

=head2 key_down

accepts a parameter describing a key and returns an action for use in the L<perform|/perform> method that corresponding with that key being depressed.

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                               )->release()->content();

=head2 key_up

accepts a parameter describing a key and returns an action for use in the L<perform|/perform> method that corresponding with that key being released.

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                                 $firefox->pause(20),
                                 $firefox->key_up('l'),
                                 $firefox->key_up(CONTROL())
                               )->content();

=head2 languages

accepts an optional list of values for the L<Accept-Language|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Language> header and sets this using the profile preferences.  It returns the current values as a list, such as ('en-US', 'en').

=head2 loaded

returns true if C<document.readyState === "complete">

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_id('metacpan_search-input')->type('Type::More');
    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();
    while(!$firefox->loaded()) {
        # redirecting to Test::More page
    }

=head2 logins

returns a list of all L<Firefox::Marionette::Login|Firefox::Marionette::Login> objects available.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $login ($firefox->logins()) {
       say "Found login for " . $login->host() . " and user " . $login->user();
    }

=head2 logins_from_csv

accepts a filehandle as a parameter and then reads the filehandle for exported logins as CSV.  This is known to work with the following formats;

=over 4

=item * L<Bitwarden CSV|https://bitwarden.com/help/article/condition-bitwarden-import/>

=item * L<LastPass CSV|https://support.logmeininc.com/lastpass/help/how-do-i-nbsp-export-stored-data-from-lastpass-using-a-generic-csv-file>

=item * L<KeePass CSV|https://keepass.info/help/base/importexport.html#csv>

=back

returns a list of L<Firefox::Marionette::Login|Firefox::Marionette::Login> objects.

    use Firefox::Marionette();
    use FileHandle();

    my $handle = FileHandle->new('/path/to/last_pass.csv');
    my $firefox = Firefox::Marionette->new();
    foreach my $login (Firefox::Marionette->logins_from_csv($handle)) {
        $firefox->add_login($login);
    }

=head2 logins_from_xml

accepts a filehandle as a parameter and then reads the filehandle for exported logins as XML.  This is known to work with the following formats;

=over 4

=item * L<KeePass 1.x XML|https://keepass.info/help/base/importexport.html#xml>

=back

returns a list of L<Firefox::Marionette::Login|Firefox::Marionette::Login> objects.

    use Firefox::Marionette();
    use FileHandle();

    my $handle = FileHandle->new('/path/to/keepass1.xml');
    my $firefox = Firefox::Marionette->new();
    foreach my $login (Firefox::Marionette->logins_from_csv($handle)) {
        $firefox->add_login($login);
    }

=head2 logins_from_zip

accepts a filehandle as a parameter and then reads the filehandle for exported logins as a zip file.  This is known to work with the following formats;

=over 4

=item * L<1Password Unencrypted Export format|https://support.1password.com/1pux-format/>

=back

returns a list of L<Firefox::Marionette::Login|Firefox::Marionette::Login> objects.

    use Firefox::Marionette();
    use FileHandle();

    my $handle = FileHandle->new('/path/to/1Passwordv8.1pux');
    my $firefox = Firefox::Marionette->new();
    foreach my $login (Firefox::Marionette->logins_from_zip($handle)) {
        $firefox->add_login($login);
    }

=head2 links

returns a list of all of the following elements;

=over 4

=item * L<anchor|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/a>

=item * L<area|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/area>

=item * L<frame|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/frame>

=item * L<iframe|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/iframe>

=item * L<meta|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta>

=back

as L<Firefox::Marionette::Link|Firefox::Marionette::Link> objects.

This method is subject to the L<implicit|Firefox::Marionette::Timeouts#implicit> timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $link = $firefox->links()) {
        if ($link->tag() eq 'a') {
            warn "Found a hyperlink to " . $link->URL();
        }
    }

If no elements are found, this method will return undef.

=head2 macos_binary_paths

returns a list of filesystem paths that this module will check for binaries that it can automate when running on L<MacOS|https://en.wikipedia.org/wiki/MacOS>.  Only of interest when sub-classing.

=head2 marionette_protocol

returns the version for the Marionette protocol.  Current most recent version is '3'.

=head2 maximise

maximises the firefox window. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 mime_types

returns a list of MIME types that will be downloaded by firefox and made available from the L<downloads|/downloads> method

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new(mime_types => [ 'application/pkcs10' ])

    foreach my $mime_type ($firefox->mime_types()) {
        say $mime_type;
    }

=head2 minimise

minimises the firefox window. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 mouse_down

accepts a parameter describing which mouse button the method should apply to (L<left|Firefox::Marionette::Buttons#LEFT>, L<middle|Firefox::Marionette::Buttons#MIDDLE> or L<right|Firefox::Marionette::Buttons#RIGHT>) and returns an action for use in the L<perform|/perform> method that corresponding with a mouse button being depressed.

=head2 mouse_move

accepts a L<element|Firefox::Marionette::Element> parameter, or a C<( x =E<gt> 0, y =E<gt> 0 )> type hash manually describing exactly where to move the mouse to and returns an action for use in the L<perform|/perform> method that corresponding with such a mouse movement, either to the specified co-ordinates or to the middle of the supplied L<element|Firefox::Marionette::Element> parameter.  Other parameters that may be passed are listed below;

=over 4

=item * origin - the origin of the C(<x =E<gt> 0, y =E<gt> 0)> co-ordinates.  Should be either C<viewport>, C<pointer> or an L<element|Firefox::Marionette::Element>.

=item * duration - Number of milliseconds over which to distribute the move. If not defined, the duration defaults to 0.

=back

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 mouse_up

accepts a parameter describing which mouse button the method should apply to (L<left|Firefox::Marionette::Buttons#LEFT>, L<middle|Firefox::Marionette::Buttons#MIDDLE> or L<right|Firefox::Marionette::Buttons#RIGHT>) and returns an action for use in the L<perform|/perform> method that corresponding with a mouse button being released.

=head2 new
 
accepts an optional hash as a parameter.  Allowed keys are below;

=over 4

=item * addons - should any firefox extensions and themes be available in this session.  This defaults to "0".

=item * binary - use the specified path to the L<Firefox|https://firefox.org/> binary, rather than the default path.

=item * capabilities - use the supplied L<capabilities|Firefox::Marionette::Capabilities> object, for example to set whether the browser should L<accept insecure certs|Firefox::Marionette::Capabilities#accept_insecure_certs> or whether the browser should use a L<proxy|Firefox::Marionette::Proxy>.

=item * chatty - Firefox is extremely chatty on the network, including checking for the latest malware/phishing sites, updates to firefox/etc.  This option is therefore off ("0") by default, however, it can be switched on ("1") if required.  Even with chatty switched off, L<connections to firefox.settings.services.mozilla.com will still be made|https://bugzilla.mozilla.org/show_bug.cgi?id=1598562#c13>.  The only way to prevent this seems to be to set firefox.settings.services.mozilla.com to 127.0.0.1 via L</etc/hosts|https://en.wikipedia.org/wiki//etc/hosts>.  NOTE: that this option only works when profile_name/profile is not specified.

=item * console - show the L<browser console|https://developer.mozilla.org/en-US/docs/Tools/Browser_Console/> when the browser is launched.  This defaults to "0" (off).  See L<CONSOLE LOGGING|/CONSOLE-LOGGING> for a discussion of how to send log messages to the console.

=item * debug - should firefox's debug to be available via STDERR. This defaults to "0". Any ssh connections will also be printed to STDERR.  This defaults to "0" (off).  This setting may be updated by the L<debug|/debug> method.  If this option is not a boolean (0|1), the value will be passed to the L<MOZ_LOG|https://firefox-source-docs.mozilla.org/networking/http/logging.html> option on the command line of the firefox binary to allow extra levels of debug.

=item * developer - only allow a L<developer edition|https://www.mozilla.org/en-US/firefox/developer/> to be launched. This defaults to "0" (off).

=item * devtools - begin the session with the L<devtools|https://developer.mozilla.org/en-US/docs/Tools> window opened in a separate window.

=item * geo - setup the browser L<preferences|http://kb.mozillazine.org/About:config> to allow the L<Geolocation API|https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API> to work.  If the value for this key is a L<URI|URI> object or a string beginning with '^(?:data|http)', this object will be retrieved using the L<json|/json> method and the response will used to build a L<GeoLocation|Firefox::Mozilla::GeoLocation> object, which will be sent to the L<geo|/geo> method.  If the value for this key is a hash, the hash will be used to build a L<GeoLocation|Firefox::Mozilla::GeoLocation> object, which will be sent to the L<geo|/geo> method.

=item * height - set the L<height|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29> of the initial firefox window

=item * har - begin the session with the L<devtools|https://developer.mozilla.org/en-US/docs/Tools> window opened in a separate window.  The L<HAR Export Trigger|https://addons.mozilla.org/en-US/firefox/addon/har-export-trigger/> addon will be loaded into the new session automatically, which means that L<-safe-mode|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29> will not be activated for this session AND this functionality will only be available for Firefox 61+.

=item * host - use L<ssh|https://man.openbsd.org/ssh.1> to create and automate firefox on the specified host.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH> and L<NETWORK ARCHITECTURE|/NETWORK-ARCHITECTURE>.  The user will default to the current user name (see the user parameter to change this).  Authentication should be via public keys loaded into the local L<ssh-agent|https://man.openbsd.org/ssh-agent>.

=item * implicit - a shortcut to allow directly providing the L<implicit|Firefox::Marionette::Timeout#implicit> timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.

=item * index - a parameter to allow the user to specify a specific firefox instance to survive and reconnect to.  It does not do anything else at the moment.  See the survive parameter.

=item * kiosk - start the browser in L<kiosk|https://support.mozilla.org/en-US/kb/firefox-enterprise-kiosk-mode> mode.

=item * mime_types - any MIME types that Firefox will encounter during this session.  MIME types that are not specified will result in a hung browser (the File Download popup will appear).

=item * nightly - only allow a L<nightly release|https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly> to be launched.  This defaults to "0" (off).

=item * port - if the "host" parameter is also set, use L<ssh|https://man.openbsd.org/ssh.1> to create and automate firefox via the specified port.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH> and L<NETWORK ARCHITECTURE|/NETWORK-ARCHITECTURE>.

=item * page_load - a shortcut to allow directly providing the L<page_load|Firefox::Marionette::Timeouts#page_load> timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.

=item * profile - create a new profile based on the supplied L<profile|Firefox::Marionette::Profile>.  NOTE: firefox ignores any changes made to the profile on the disk while it is running, instead, use the L<set_pref|/set_pref> and L<clear_pref|/clear_pref> methods to make changes while firefox is running.

=item * profile_name - pick a specific existing profile to automate, rather than creating a new profile.  L<Firefox|https://firefox.com> refuses to allow more than one instance of a profile to run at the same time.  Profile names can be obtained by using the L<Firefox::Marionette::Profile::names()|Firefox::Marionette::Profile#names> method.  NOTE: firefox ignores any changes made to the profile on the disk while it is running, instead, use the L<set_pref|/set_pref> and L<clear_pref|/clear_pref> methods to make changes while firefox is running.

=item * proxy - this is a shortcut method for setting a L<proxy|Firefox::Marionette::Proxy> using the L<capabilities|Firefox::Marionette::Capabilities> parameter above.  It accepts a proxy URL, with the following allowable schemes, 'http' and 'https'.  It also allows a reference to a list of proxy URLs which will function as list of proxies that Firefox will try in L<left to right order|https://developer.mozilla.org/en-US/docs/Web/HTTP/Proxy_servers_and_tunneling/Proxy_Auto-Configuration_PAC_file#description> until a working proxy is found.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH>, L<NETWORK ARCHITECTURE|/NETWORK-ARCHITECTURE> and L<SETTING UP SOCKS SERVERS USING SSH|Firefox::Marionette::Proxy#SETTING-UP-SOCKS-SERVERS-USING-SSH>.

=item * reconnect - an experimental parameter to allow a reconnection to firefox that a connection has been discontinued.  See the survive parameter.

=item * scp - force the scp protocol when transferring files to remote hosts via ssh. See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH> and the --scp-only option in the L<ssh-auth-cmd-marionette|ssh-auth-cmd-marionette> script in this distribution.

=item * script - a shortcut to allow directly providing the L<script|Firefox::Marionette::Timeout#script> timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.

=item * seer - this option is switched off "0" by default.  When it is switched on "1", it will activate the various speculative and pre-fetch options for firefox.  NOTE: that this option only works when profile_name/profile is not specified.

=item * sleep_time_in_ms - the amount of time (in milliseconds) that this module should sleep when unsuccessfully calling the subroutine provided to the L<await|/await> or L<bye|/bye> methods.  This defaults to "1" millisecond.

=item * survive - if this is set to a true value, firefox will not automatically exit when the object goes out of scope.  See the reconnect parameter for an experimental technique for reconnecting.

=item * trust - give a path to a L<root certificate|https://en.wikipedia.org/wiki/Root_certificate> encoded as a L<PEM encoded X.509 certificate|https://datatracker.ietf.org/doc/html/rfc7468#section-5> that will be trusted for this session.

=item * timeouts - a shortcut to allow directly providing a L<timeout|Firefox::Marionette::Timeout> object, instead of needing to use timeouts from the capabilities parameter.  Overrides the timeouts provided (if any) in the capabilities parameter.

=item * user - if the "host" parameter is also set, use L<ssh|https://man.openbsd.org/ssh.1> to create and automate firefox with the specified user.  See L<REMOTE AUTOMATION OF FIREFOX VIA SSH|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH> and L<NETWORK ARCHITECTURE|/NETWORK-ARCHITECTURE>.  The user will default to the current user name.  Authentication should be via public keys loaded into the local L<ssh-agent|https://man.openbsd.org/ssh-agent>.

=item * via - specifies a L<proxy jump box|https://man.openbsd.org/ssh_config#ProxyJump> to be used to connect to a remote host.  See the host parameter.

=item * visible - should firefox be visible on the desktop.  This defaults to "0".  When moving from a X11 platform to another X11 platform, you can set visible to 'local' to enable L<X11 forwarding|https://man.openbsd.org/ssh#X>.  See L<X11 FORWARDING WITH FIREFOX|/X11-FORWARDING-WITH-FIREFOX>.

=item * waterfox - only allow a binary that looks like a L<waterfox version|https://www.waterfox.net/> to be launched.

=item * webauthn - a boolean parameter to determine whether or not to L<add a webauthn authenticator|/add_webauthn_authenticator> after the connection is established.  The default is to add a webauthn authenticator for Firefox after version 118.

=item * width - set the L<width|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29> of the initial firefox window

=back

This method returns a new C<Firefox::Marionette> object, connected to an instance of L<firefox|https://firefox.com>.  In a non MacOS/Win32/Cygwin environment, if necessary (no DISPLAY variable can be found and the visible parameter to the new method has been set to true) and possible (Xvfb can be executed successfully), this method will also automatically start an L<Xvfb|https://en.wikipedia.org/wiki/Xvfb> instance.
 
    use Firefox::Marionette();

    my $remote_darwin_firefox = Firefox::Marionette->new(
                     debug => 'timestamp,nsHttp:1',
                     host => '10.1.2.3',
                     trust => '/path/to/root_ca.pem',
                     binary => '/Applications/Firefox.app/Contents/MacOS/firefox'
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

Returns the L<window handle|Firefox::Marionette::WebWindow> for the new window.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $window_handle = $firefox->new_window(type => 'tab');

    $firefox->switch_to_window($window_handle);

=head2 new_session

creates a new WebDriver session.  It is expected that the caller performs the necessary checks on the requested capabilities to be WebDriver conforming.  The WebDriver service offered by Marionette does not match or negotiate capabilities beyond type and bounds checks.

=head2 nightly

returns true if the L<current version|/browser_version> of firefox is a L<nightly release|https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly> (does the minor version number end with an 'a1'?)

=head2 paper_sizes 

returns a list of all the recognised names for paper sizes, such as A4 or LEGAL.

=head2 pause

accepts a parameter in milliseconds and returns a corresponding action for the L<perform|/perform> method that will cause a pause in the chain of actions given to the L<perform|/perform> method.

=head2 pdf

accepts a optional hash as the first parameter with the following allowed keys;

=over 4

=item * landscape - Paper orientation.  Boolean value.  Defaults to false

=item * margin - A hash describing the margins.  The hash may have the following optional keys, 'top', 'left', 'right' and 'bottom'.  All these keys are in cm and default to 1 (~0.4 inches)

=item * page - A hash describing the page.  The hash may have the following keys; 'height' and 'width'.  Both keys are in cm and default to US letter size.  See the 'size' key.

=item * page_ranges - A list of the pages to print. Available for L<Firefox 96|https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/96#webdriver_conformance_marionette> and after.

=item * print_background - Print background graphics.  Boolean value.  Defaults to false. 

=item * raw - rather than a file handle containing the PDF, the binary PDF will be returned.

=item * scale - Scale of the webpage rendering.  Defaults to 1.  C<shrink_to_fit> should be disabled to make C<scale> work.

=item * size - The desired size (width and height) of the pdf, specified by name.  See the page key for an alternative and the L<paper_sizes|/paper_sizes> method for a list of accepted page size names. 

=item * shrink_to_fit - Whether or not to override page size as defined by CSS.  Boolean value.  Defaults to true. 

=back

returns a L<File::Temp|File::Temp> object containing a PDF encoded version of the current page for printing.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $handle = $firefox->pdf();
    foreach my $paper_size ($firefox->paper_sizes()) {
	    $handle = $firefox->pdf(size => $paper_size, landscape => 1, margin => { top => 0.5, left => 1.5 });
            ...
	    print $firefox->pdf(page => { width => 21, height => 27 }, raw => 1);
            ...
    }

=head2 percentage_visible

accepts an L<element|Firefox::Marionette::Element> as the first parameter and returns the percentage of that L<element|Firefox::Marionette::Element> that is currently visible in the L<viewport|https://developer.mozilla.org/en-US/docs/Glossary/Viewport>.  It achieves this by determining the co-ordinates of the L<DOMRect|https://developer.mozilla.org/en-US/docs/Web/API/DOMRect> with a L<getBoundingClientRect|https://developer.mozilla.org/en-US/docs/Web/API/Element/getBoundingClientRect> call and then using L<elementsFromPoint|https://developer.mozilla.org/en-US/docs/Web/API/Document/elementsFromPoint> and L<getComputedStyle|https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle> calls to determine how the percentage of the L<DOMRect|https://developer.mozilla.org/en-US/docs/Web/API/DOMRect> that is visible to the user.  The L<getComputedStyle|https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle> call is used to determine the state of the L<visibility|https://developer.mozilla.org/en-US/docs/Web/CSS/visibility> and L<display|https://developer.mozilla.org/en-US/docs/Web/CSS/display> attributes.

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    my $element = $firefox->find_id('metacpan_search-input');
    my $totally_viewable_percentage = $firefox->percentage_visible($element); # search box is slightly hidden by different effects
    foreach my $display ($firefox->displays()) {
        if ($firefox->resize($display->width(), $display->height())) {
            if ($firefox->percentage_visible($element) < $totally_viewable_percentage) {
               say 'Search box stops being fully viewable with ' . Encode::encode('UTF-8', $display->usage());
               last;
            }
        }
    }

=head2 perform

accepts a list of actions (see L<mouse_up|/mouse_up>, L<mouse_down|/mouse_down>, L<mouse_move|/mouse_move>, L<pause|/pause>, L<key_down|/key_down> and L<key_up|/key_up>) and performs these actions in sequence.  This allows fine control over interactions, including sending right clicks to the browser and sending Control, Alt and other special keys.  The L<release|/release> method will complete outstanding actions (such as L<mouse_up|/mouse_up> or L<key_up|/key_up> actions).

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);
    use Firefox::Marionette::Buttons qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                                 $firefox->key_up('l'),
                                 $firefox->key_up(CONTROL())
                               )->content();

    $firefox->go('https://metacpan.org');
    my $help_button = $firefox->find_class('btn search-btn help-btn');
    $firefox->perform(
			          $firefox->mouse_move($help_button),
			          $firefox->mouse_down(RIGHT_BUTTON()),
			          $firefox->pause(4),
			          $firefox->mouse_up(RIGHT_BUTTON()),
		);

See the L<release|/release> method for an alternative for manually specifying all the L<mouse_up|/mouse_up> and L<key_up|/key_up> methods

=head2 profile_directory

returns the profile directory used by the current instance of firefox.  This is mainly intended for debugging firefox.  Firefox is not designed to cope with these files being altered while firefox is running.

=head2 property

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a scalar attribute name as the second parameter.  It returns the current value of the property with the supplied name.  This method will return the current content, the L<attribute|/attribute> method will return the initial content from the HTML source code.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_id('metacpan_search-input');
    $element->property('value') eq '' or die "Initial property should be the empty string";
    $element->type('Test::More');
    $element->property('value') eq 'Test::More' or die "This property should have changed!";

    # OR getting the innerHTML property

    my $title = $firefox->find_tag('title')->property('innerHTML'); # same as $firefox->title();

=head2 pwd_mgr_lock

Accepts a new L<primary password|https://support.mozilla.org/en-US/kb/use-primary-password-protect-stored-logins> and locks the L<Password Manager|https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins> with it.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new();
    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
    $firefox->pwd_mgr_lock($password);
    $firefox->pwd_mgr_logout();
    # now no-one can access the Password Manager Database without the value in $password

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 pwd_mgr_login

Accepts the L<primary password|https://support.mozilla.org/en-US/kb/use-primary-password-protect-stored-logins> and allows the user to access the L<Password Manager|https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins>.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
    $firefox->pwd_mgr_login($password);
    ...
    # access the Password Database.
    ...
    $firefox->pwd_mgr_logout();
    ...
    # no longer able to access the Password Database.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 pwd_mgr_logout

Logs the user out of being able to access the L<Password Manager|https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins>.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
    $firefox->pwd_mgr_login($password);
    ...
    # access the Password Database.
    ...
    $firefox->pwd_mgr_logout();
    ...
    # no longer able to access the Password Database.

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 pwd_mgr_needs_login

returns true or false if the L<Password Manager|https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins> has been locked and needs a L<primary password|https://support.mozilla.org/en-US/kb/use-primary-password-protect-stored-logins> to access it.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    if ($firefox->pwd_mgr_needs_login()) {
      my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
      $firefox->pwd_mgr_login($password);
    }

=head2 quit

Marionette will stop accepting new connections before ending the current session, and finally attempting to quit the application.  This method returns the $? (CHILD_ERROR) value for the Firefox process

=head2 rect

accepts a L<element|Firefox::Marionette::Element> as the first parameter and returns the current L<position and size|Firefox::Marionette::Element::Rect> of the L<element|Firefox::Marionette::Element>

=head2 refresh

refreshes the current page.  The browser will wait for the page to completely refresh or the session's L<page_load|Firefox::Marionette::Timeouts#page_load> duration to elapse before returning, which, by default is 5 minutes.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 release

completes any outstanding actions issued by the L<perform|/perform> method.

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);
    use Firefox::Marionette::Buttons qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                               )->release()->content();

    $firefox->go('https://metacpan.org');
    my $help_button = $firefox->find_class('btn search-btn help-btn');
    $firefox->perform(
			          $firefox->mouse_move($help_button),
			          $firefox->mouse_down(RIGHT_BUTTON()),
			          $firefox->pause(4),
		)->release();

=head2 resize

accepts width and height parameters in a list and then attempts to resize the entire browser to match those parameters.  Due to the oddities of various window managers, this function needs to manually calculate what the maximum and minimum sizes of the display is.  It does this by;

=over 4

=item 1 performing a L<maximise|Firefox::Marionette::maximise>, then

=item 2 caching the browser's current width and height as the maximum width and height. It

=item 3 then calls L<resizeTo|https://developer.mozilla.org/en-US/docs/Web/API/Window/resizeTo> to resize the window to 0,0

=item 4 wait for the browser to send a L<resize|https://developer.mozilla.org/en-US/docs/Web/API/Window/resize_event> event.

=item 5 cache the browser's current width and height as the minimum width and height

=item 6 if the requested width and height are outside of the maximum and minimum widths and heights return false

=item 7 if the requested width and height matches the current width and height return L<itself|Firefox::Marionette> to aid in chaining methods. Otherwise,

=item 8 call L<resizeTo|https://developer.mozilla.org/en-US/docs/Web/API/Window/resizeTo> for the requested width and height

=item 9 wait for the L<resize|https://developer.mozilla.org/en-US/docs/Web/API/Window/resize_event> event

=back

This method returns L<itself|Firefox::Marionette> to aid in chaining methods if the method succeeds, otherwise it returns false.

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    if ($firefox->resize(1024, 768)) {
        say 'We are showing an XGA display';
    } else {
       say 'Resize failed to work';
    }

=head2 restart

restarts the browser.  After the restart, L<capabilities|Firefox::Marionette::Capabilities> should be restored.  The same profile settings should be applied, but the current state of the browser (such as the L<uri|/uri> will be reset (like after a normal browser restart).  This method is primarily intended for use by the L<update|/update> method.  Not sure if this is useful by itself.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    $firefox->restart(); # but why?

This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 root_directory

this is the root directory for the current instance of firefox.  The directory may exist on a remote server.  For debugging purposes only.

=head2 screen_orientation

returns the current browser orientation.  This will be one of the valid primary orientation values 'portrait-primary', 'landscape-primary', 'portrait-secondary', or 'landscape-secondary'.  This method is only currently available on Android (Fennec).

=head2 script 

accepts a scalar containing a javascript function body that is executed in the browser, and an optional hash as a second parameter.  Allowed keys are below;

=over 4

=item * args - The reference to a list is the arguments passed to the function body.

=item * filename - Filename of the client's program where this script is evaluated.

=item * line - Line in the client's program where this script is evaluated.

=item * new - Forces the script to be evaluated in a fresh sandbox.  Note that if it is undefined, the script will normally be evaluated in a fresh sandbox.

=item * sandbox - Name of the sandbox to evaluate the script in.  The sandbox is cached for later re-use on the same L<window|https://developer.mozilla.org/en-US/docs/Web/API/Window> object if C<new> is false.  If he parameter is undefined, the script is evaluated in a mutable sandbox.  If the parameter is "system", it will be evaluated in a sandbox with elevated system privileges, equivalent to chrome space.

=item * timeout - A timeout to override the default L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.

=back

Returns the result of the javascript function.  When a parameter is an L<element|Firefox::Marionette::Element> (such as being returned from a L<find|/find> type operation), the L<script|/script> method will automatically translate that into a javascript object.  Likewise, when the result being returned in a L<script|/script> method is an L<element|https://dom.spec.whatwg.org/#concept-element> it will be automatically translated into a L<perl object|Firefox::Marionette::Element>.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if (my $element = $firefox->script('return document.getElementsByName("metacpan_search-input")[0];')) {
        say "Lucky find is a " . $element->tag_name() . " element";
    }

    my $search_input = $firefox->find_id('metacpan_search-input');

    $firefox->script('arguments[0].style.backgroundColor = "red"', args => [ $search_input ]); # turn the search input box red

The executing javascript is subject to the L<script|Firefox::Marionette::Timeouts#script> timeout, which, by default is 30 seconds.

=head2 selfie

returns a L<File::Temp|File::Temp> object containing a lossless PNG image screenshot.  If an L<element|Firefox::Marionette::Element> is passed as a parameter, the screenshot will be restricted to the element.  

If an L<element|Firefox::Marionette::Element> is not passed as a parameter and the current L<context|/context> is 'chrome', a screenshot of the current viewport will be returned.

If an L<element|Firefox::Marionette::Element> is not passed as a parameter and the current L<context|/context> is 'content', a screenshot of the current frame will be returned.

The parameters after the L<element|Firefox::Marionette::Element> parameter are taken to be a optional hash with the following allowed keys;

=over 4

=item * hash - return a SHA256 hex encoded digest of the PNG image rather than the image itself

=item * full - take a screenshot of the whole document unless the first L<element|Firefox::Marionette::Element> parameter has been supplied.

=item * raw - rather than a file handle containing the screenshot, the binary PNG image will be returned.

=item * scroll - scroll to the L<element|Firefox::Marionette::Element> supplied

=item * highlights - a reference to a list containing L<elements|Firefox::Marionette::Element> to draw a highlight around.  Not available in L<Firefox 70|https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/70#WebDriver_conformance_Marionette> onwards.

=back

=head2 scroll

accepts a L<element|Firefox::Marionette::Element> as the first parameter and L<scrolls|https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView> to it.  The optional second parameter is the same as for the L<scrollInfoView|https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView> method.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(visible => 1)->go('https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView');
    my $link = $firefox->find_id('content')->find_link('Examples');
    $firefox->scroll($link);
    $firefox->scroll($link, 1);
    $firefox->scroll($link, { behavior => 'smooth', block => 'center' });
    $firefox->scroll($link, { block => 'end', inline => 'nearest' });

=head2 send_alert_text

sends keys to the input field of a currently displayed modal message box

=head2 set_pref

accepts a L<preference|http://kb.mozillazine.org/About:config> name and the new value to set it to.  See the L<get_pref|/get_pref> and L<clear_pref|/clear_pref> methods to get a preference value and to restore it to it's original value.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();
    my $firefox = Firefox::Marionette->new();
    ...
    $firefox->set_pref('browser.search.defaultenginename', 'DuckDuckGo');

=head2 shadow_root

accepts an L<element|Firefox::Marionette::Element> as a parameter and returns it's L<ShadowRoot|https://developer.mozilla.org/en-US/docs/Web/API/ShadowRoot> as a L<shadow root|Firefox::Marionette::ShadowRoot> object or throws an exception.

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new()->go('file://' . Cwd::cwd() . '/t/data/elements.html');

    $firefox->find_class('add')->click();
    my $custom_square = $firefox->find_tag('custom-square');
    my $shadow_root = $firefox->shadow_root($custom_square);

    foreach my $element (@{$firefox->script('return arguments[0].children', args => [ $shadow_root ])}) {
        warn $element->tag_name();
    }

See the L<FINDING ELEMENTS IN A SHADOW DOM|/FINDING-ELEMENTS-IN-A-SHADOW-DOM> section for how to delve into a L<shadow DOM|https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM>.

=head2 shadowy

accepts an L<element|Firefox::Marionette::Element> as a parameter and returns true if the element has a L<ShadowRoot|https://developer.mozilla.org/en-US/docs/Web/API/ShadowRoot> or false otherwise.

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new()->go('file://' . Cwd::cwd() . '/t/data/elements.html');
    $firefox->find_class('add')->click();
    my $custom_square = $firefox->find_tag('custom-square');
    if ($firefox->shadowy($custom_square)) {
        my $shadow_root = $firefox->find_tag('custom-square')->shadow_root();
        warn $firefox->script('return arguments[0].innerHTML', args => [ $shadow_root ]);
        ...
    }

This function will probably be used to see if the L<shadow_root|Firefox::Marionette::Element#shadow_root> method can be called on this element without raising an exception.

=head2 sleep_time_in_ms

accepts a new time to sleep in L<await|/await> or L<bye|/bye> methods and returns the previous time.  The default time is "1" millisecond.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(sleep_time_in_ms => 5); # setting default time to 5 milliseconds

    my $old_time_in_ms = $firefox->sleep_time_in_ms(8); # setting default time to 8 milliseconds, returning 5 (milliseconds)

=head2 ssh_local_directory

returns the path to the local directory for the ssh connection (if any). For debugging purposes only.

=head2 strip

returns the page source of the content document after an attempt has been made to remove typical firefox html wrappers of non html content types such as text/plain and application/json.  See the L<json|/json> method for an alternative when dealing with response content types such as application/json and L<html|/html> for an alternative when dealing with html content types.  This is a convenience method that wraps the L<html|/html> method.

    use Firefox::Marionette();
    use JSON();
    use v5.10;

    say JSON::decode_json(Firefox::Marionette->new()->go("https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette")->strip())->{version};

Note that this method will assume the bytes it receives from the L<html|/html> method are UTF-8 encoded and will translate accordingly, throwing an exception in the process if the bytes are not UTF-8 encoded.

=head2 switch_to_frame

accepts a L<frame|Firefox::Marionette::Element> as a parameter and switches to it within the current window.

=head2 switch_to_parent_frame

set the current browsing context for future commands to the parent of the current browsing context

=head2 switch_to_window

accepts a L<window handle|Firefox::Marionette::WebWindow> (either the result of L<window_handles|/window_handles> or a window name as a parameter and switches focus to this window.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->version
    my $original_window = $firefox->window_handle();
    $firefox->new_window( type => 'tab' );
    $firefox->new_window( type => 'window' );
    $firefox->switch_to_window($original_window);
    $firefox->go('https://metacpan.org');

=head2 tag_name

accepts a L<Firefox::Marionette::Element|Firefox::Marionette::Element> object as the first parameter and returns the relevant tag name.  For example 'L<a|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/a>' or 'L<input|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input>'.

=head2 text

accepts a L<element|Firefox::Marionette::Element> as the first parameter and returns the text that is contained by that element (if any)

=head2 timeouts

returns the current L<timeouts|Firefox::Marionette::Timeouts> for page loading, searching, and scripts.

=head2 title

returns the current L<title|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/title> of the window.

=head2 type

accepts an L<element|Firefox::Marionette::Element> as the first parameter and a string as the second parameter.  It sends the string to the specified L<element|Firefox::Marionette::Element> in the current page, such as filling out a text box. This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

=head2 uname

returns the $^O ($OSNAME) compatible string to describe the platform where firefox is running.

=head2 update

queries the Update Services and applies any available updates.  L<Restarts|/restart> the browser if necessary to complete the update.  This function is experimental and currently has not been successfully tested on Win32 or MacOS.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    my $update = $firefox->update();

    while($update->successful()) {
        $update = $firefox->update();
    }

    say "Updated to " . $update->display_version() . " - Build ID " . $update->build_id();

    $firefox->quit();

returns a L<status|Firefox::Marionette::UpdateStatus> object that contains useful information about any updates that occurred.

=head2 uninstall

accepts the GUID for the addon to uninstall.  The GUID is returned when from the L<install|/install> method.  This method returns L<itself|Firefox::Marionette> to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $extension_id = $firefox->install('/full/path/to/gnu_terry_pratchett-0.4-an+fx.xpi');

    # do something

    $firefox->uninstall($extension_id); # not recommended to uninstall this extension IRL.

=head2 uri

returns the current L<URI|URI> of current top level browsing context for Desktop.  It is equivalent to the javascript C<document.location.href>

=head2 webauthn_authenticator

returns the default L<WebAuthn authenticator|Firefox::Marionette::WebAuthn::Authenticator> created when the L<new|/new> method was called.

=head2 webauthn_credentials

This method accepts an optional L<authenticator|Firefox::Marionette::WebAuthn::Authenticator>, in which case it will return all the L<credentials|Firefox::Marionette::WebAuthn::Credential> attached to this authenticator.  If no parameter is supplied, L<credentials|Firefox::Marionette::WebAuthn::Credential> from the default authenticator will be returned.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $credential ($firefox->webauthn_credentials()) {
       say "Credential host is " . $credential->host();
    }

    # OR

    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
       say "Credential host is " . $credential->host();
    }

=head2 webauthn_set_user_verified

This method accepts a boolean for the L<is_user_verified|Firefox::Marionette::WebAuthn::Authenticator#is_user_verified> field and an optional L<authenticator|Firefox::Marionette::WebAuthn::Authenticator> (the default authenticator will be used otherwise).  It sets the L<is_user_verified|Firefox::Marionette::WebAuthn::Authenticator#is_user_verified> field to the supplied boolean value.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->webauthn_set_user_verified(1);

=head2 wheel

accepts a L<element|Firefox::Marionette::Element> parameter, or a C<( x =E<gt> 0, y =E<gt> 0 )> type hash manually describing exactly where to move the mouse from and returns an action for use in the L<perform|/perform> method that corresponding with such a wheel action, either to the specified co-ordinates or to the middle of the supplied L<element|Firefox::Marionette::Element> parameter.  Other parameters that may be passed are listed below;

=over 4

=item * origin - the origin of the C(<x =E<gt> 0, y =E<gt> 0)> co-ordinates.  Should be either C<viewport>, C<pointer> or an L<element|Firefox::Marionette::Element>.

=item * duration - Number of milliseconds over which to distribute the move. If not defined, the duration defaults to 0.

=item * deltaX - the change in X co-ordinates during the wheel.  If not defined, deltaX defaults to 0.

=item * deltaY - the change in Y co-ordinates during the wheel.  If not defined, deltaY defaults to 0.

=back

=head2 win32_organisation

accepts a parameter of a Win32 product name and returns the matching organisation.  Only of interest when sub-classing.

=head2 win32_product_names

returns a hash of known Windows product names (such as 'Mozilla Firefox') with priority orders.  The lower the priority will determine the order that this module will check for the existence of this product.  Only of interest when sub-classing.

=head2 window_handle

returns the L<current window's handle|Firefox::Marionette::WebWindow>. On desktop this typically corresponds to the currently selected tab.  returns an opaque server-assigned identifier to this window that uniquely identifies it within this Marionette instance.  This can be used to switch to this window at a later point.  This is the same as the L<window|https://developer.mozilla.org/en-US/docs/Web/API/Window> object in Javascript.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    my $original_window = $firefox->window_handle();
    my $javascript_window = $firefox->script('return window'); # only works for Firefox 121 and later
    if ($javascript_window ne $original_window) {
        die "That was unexpected!!! What happened?";
    }

=head2 window_handles

returns a list of top-level L<browsing contexts|Firefox::Marionette::WebWindow>. On desktop this typically corresponds to the set of open tabs for browser windows, or the window itself for non-browser chrome windows.  Each window handle is assigned by the server and is guaranteed unique, however the return array does not have a specified ordering.

    use Firefox::Marionette();
    use 5.010;

    my $firefox = Firefox::Marionette->new();
    my $original_window = $firefox->window_handle();
    $firefox->new_window( type => 'tab' );
    $firefox->new_window( type => 'window' );
    say "There are " . $firefox->window_handles() . " tabs open in total";
    say "Across " . $firefox->chrome()->window_handles()->content() . " chrome windows";

=head2 window_rect

accepts an optional L<position and size|Firefox::Marionette::Window::Rect> as a parameter, sets the current browser window to that position and size and returns the previous L<position, size and state|Firefox::Marionette::Window::Rect> of the browser window.  If no parameter is supplied, it returns the current  L<position, size and state|Firefox::Marionette::Window::Rect> of the browser window.

=head2 window_type

returns the current window's type.  This should be 'navigator:browser'.

=head2 xvfb_pid

returns the pid of the xvfb process if it exists.

=head2 xvfb_display

returns the value for the DISPLAY environment variable if one has been generated for the xvfb environment.

=head2 xvfb_xauthority

returns the value for the XAUTHORITY environment variable if one has been generated for the xvfb environment

=head1 NETWORK ARCHITECTURE

This module allows for a complicated network architecture, including SSH and HTTP proxies.

  my $firefox = Firefox::Marionette->new(
                  host  => 'Firefox.runs.here'
                  via   => 'SSH.Jump.Box',
                  trust => '/path/to/ca-for-squid-proxy-server.crt',
                  proxy => 'https://Squid.Proxy.Server:3128'
                     )->go('https://Target.Web.Site');

produces the following effect, with an ascii box representing a separate network node.

     ---------          ----------         -----------
     | Perl  |  SSH     | SSH    |  SSH    | Firefox |
     | runs  |--------->| Jump   |-------->| runs    |
     | here  |          | Box    |         | here    |
     ---------          ----------         -----------
                                                |
     ----------          ----------             |
     | Target |  HTTPS   | Squid  |    TLS      |
     | Web    |<---------| Proxy  |<-------------
     | Site   |          | Server |
     ----------          ----------

In addition, the proxy parameter can be used to specify multiple proxies using a reference
to a list.

  my $firefox = Firefox::Marionette->new(
                  host  => 'Firefox.runs.here'
                  trust => '/path/to/ca-for-squid-proxy-server.crt',
                  proxy => [ 'https://Squid1.Proxy.Server:3128', 'https://Squid2.Proxy.Server:3128' ]
                     )->go('https://Target.Web.Site');

When firefox gets a list of proxies, it will use the first one that works.  In addition, it will perform a basic form of proxy failover, which may involve a failed network request before it fails over to the next proxy.  In the diagram below, Squid1.Proxy.Server is the first proxy in the list and will be used exclusively, unless it is unavailable, in which case Squid2.Proxy.Server will be used.

                                          ----------
                                     TLS  | Squid1 |
                                   ------>| Proxy  |-----
                                   |      | Server |    |
     ---------      -----------    |      ----------    |       -----------
     | Perl  | SSH  | Firefox |    |                    | HTTPS | Target  |
     | runs  |----->| runs    |----|                    ------->| Web     |
     | here  |      | here    |    |                    |       | Site    |
     ---------      -----------    |      ----------    |       -----------
                                   | TLS  | Squid2 |    |
                                   ------>| Proxy  |-----
                                          | Server |
                                          ----------

See the L<REMOTE AUTOMATION OF FIREFOX VIA SSH|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH> section for more options.

See L<SETTING UP SOCKS SERVERS USING SSH|Firefox::Marionette::Proxy#SETTING-UP-SOCKS-SERVERS-USING-SSH> for easy proxying via L<ssh|https://man.openbsd.org/ssh>

See L<GEO LOCATION|/GEO-LOCATION> section for how to combine this with providing appropriate browser settings for the end point.

=head1 AUTOMATING THE FIREFOX PASSWORD MANAGER

This module allows you to login to a website without ever directly handling usernames and password details.  The Password Manager may be preloaded with appropriate passwords and locked, like so;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( profile_name => 'locked' ); # using a pre-built profile called 'locked'
    if ($firefox->pwd_mgr_needs_login()) {
        my $new_password = IO::Prompt::prompt(-echo => q[*], 'Enter the password for the locked profile:');
        $firefox->pwd_mgr_login($password);
    } else {
        my $new_password = IO::Prompt::prompt(-echo => q[*], 'Enter the new password for the locked profile:');
        $firefox->pwd_mgr_lock($password);
    }
    ...
    $firefox->pwd_mgr_logout();

Usernames and passwords (for both HTTP Authentication popups and HTML Form based logins) may be added, viewed and deleted.

    use WebService::HIBP();

    my $hibp = WebService::HIBP->new();

    $firefox->add_login(host => 'https://github.com', user => 'me@example.org', password => 'qwerty', user_field => 'login', password_field => 'password');
    $firefox->add_login(host => 'https://pause.perl.org', user => 'AUSER', password => 'qwerty', realm => 'PAUSE');
    ...
    foreach my $login ($firefox->logins()) {
        if ($hibp->password($login->password())) { # does NOT send the password to the HIBP webservice
            warn "HIBP reports that your password for the " . $login->user() " account at " . $login->host() . " has been found in a data breach";
            $firefox->delete_login($login); # how could this possibly help?
        }
    }

And used to fill in login prompts without explicitly knowing the account details.

    $firefox->go('https://pause.perl.org/pause/authenquery')->accept_alert(); # this goes to the page and submits the http auth popup

    $firefox->go('https://github.com/login')->fill_login(); # fill the login and password fields without needing to see them

=head1 GEO LOCATION

The firefox L<Geolocation API|https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API> can be used by supplying the C<geo> parameter to the L<new|/new> method and then calling the L<geo|/geo> method (from a L<secure context|https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts>.

The L<geo|/geo> method can accept various specific latitude and longitude parameters as a list, such as;

    $firefox->geo(latitude => -37.82896, longitude => 144.9811);

    OR

    $firefox->geo(lat => -37.82896, long => 144.9811);

    OR

    $firefox->geo(lat => -37.82896, lng => 144.9811);

    OR

    $firefox->geo(lat => -37.82896, lon => 144.9811);

or it can be passed in as a reference, such as;

    $firefox->geo({ latitude => -37.82896, longitude => 144.9811 });

the combination of a variety of parameter names and the ability to pass parameters in as a reference means it can be deal with various geo location websites, such as;

    $firefox->geo($firefox->json('https://freeipapi.com/api/json/')); # get geo location from IP address

    $firefox->geo($firefox->json('https://geocode.maps.co/search?street=101+Collins+St&city=Melbourne&state=VIC&postalcode=3000&country=AU&format=json')->[0]); # get geo location of street address

    $firefox->geo($firefox->json('http://api.positionstack.com/v1/forward?access_key=' . $access_key . '&query=101+Collins+St,Melbourne,VIC+3000')->{data}->[0]); # get geo location of street address using api key

    $firefox->geo($firefox->json('https://api.ipgeolocation.io/ipgeo?apiKey=' . $api_key)); # get geo location from IP address

These sites were active at the time this documentation was written, but mainly function as an illustration of the flexibility of L<geo|/geo> and L<json|/json> methods in providing the desired location to the L<Geolocation API|https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API>.

The L<country_code|Firefox::Marionette::GeoLocation#country_code> and L<timezone_offset|Firefox::Marionette::GeoLocation#timezone_offset> methods can be used to help set the L<languages|/languages> method and possibly in the future change the timezone of the browser.

=head1 CONSOLE LOGGING

Sending debug to the console can be quite confusing in firefox, as some techniques won't work in L<chrome|/chrome> context.  The following example can be quite useful.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( visible => 1, devtools => 1, console => 1, devtools => 1 );

    $firefox->script( q[console.log("This goes to devtools b/c it's being generated in content mode")]);

    $firefox->chrome()->script( q[console.log("Can't be seen b/c it's in chrome mode")]);

    $firefox->chrome()->script( q[const { console } = ChromeUtils.import("resource://gre/modules/Console.jsm"); console.log("Find me in the browser console in chrome mode")]);

    # This won't work b/c of permissions
    #
    # $firefox->content()->script( q[const { console } = ChromeUtils.import("resource://gre/modules/Console.jsm"); console.log("Find me in the browser console in content mode")]);

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

    # OR use a proxy host to jump via to the final host

    my $firefox = Firefox::Marionette->new(
                                             host  => 'remote.example.org',
                                             port  => 2222,
                                             via   => 'user@secure-jump-box.example.org:42222',
                                             debug => 1,
                                          );
    $firefox->go('https://metacpan.org/');

This module has support for creating and automating an instance of Firefox on a remote node.  It has been tested against a number of operating systems, including recent version of L<Windows 10 or Windows Server 2019|https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse>, OS X, and Linux and BSD distributions.  It expects to be able to login to the remote node via public key authentication.  It can be further secured via the L<command|https://man.openbsd.org/sshd#command=_command_> option in the L<OpenSSH|https://www.openssh.com/> L<authorized_keys|https://man.openbsd.org/sshd#AUTHORIZED_KEYS_FILE_FORMAT> file such as;

    no-agent-forwarding,no-pty,no-X11-forwarding,permitopen="127.0.0.1:*",command="/usr/local/bin/ssh-auth-cmd-marionette" ssh-rsa AAAA ... == user@server

As an example, the L<ssh-auth-cmd-marionette|ssh-auth-cmd-marionette> command is provided as part of this distribution.

The module will expect to access private keys via the local L<ssh-agent|https://man.openbsd.org/ssh-agent> when authenticating.

When using ssh, Firefox::Marionette will attempt to pass the L<TMPDIR|https://en.wikipedia.org/wiki/TMPDIR> environment variable across the ssh connection to make cleanups easier.  In order to allow this, the L<AcceptEnv|https://man.openbsd.org/sshd_config#AcceptEnv> setting in the remote L<sshd configuration|https://man.openbsd.org/sshd_config> should be set to allow TMPDIR, which will look like;

    AcceptEnv TMPDIR

This module uses L<ControlMaster|https://man.openbsd.org/ssh_config#ControlMaster> functionality when using L<ssh|https://man.openbsd.org/ssh>, for a useful speedup of executing remote commands.  Unfortunately, when using ssh to move from a L<cygwin|https://gcc.gnu.org/wiki/SSH_connection_caching>, L<Windows 10 or Windows Server 2019|https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse> node to a remote environment, we cannot use L<ControlMaster|https://man.openbsd.org/ssh_config#ControlMaster>, because at this time, Windows L<does not support ControlMaster|https://github.com/Microsoft/vscode-remote-release/issues/96> and therefore this type of automation is still possible, but slower than other client platforms.

The L<NETWORK ARCHITECTURE|/NETWORK-ARCHITECTURE> section has an example of a more complicated network design.

=head1 WEBGL

There are a number of steps to getting L<WebGL|https://en.wikipedia.org/wiki/WebGL> to work correctly;

=over

=item 1. The addons parameter to the L<new|/new> method must be set.  This will disable L<-safe-mode|http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29>

=item 2. The visible parameter to the L<new|/new> method must be set.  This is due to L<an existing bug in Firefox|https://bugzilla.mozilla.org/show_bug.cgi?id=1375585>.

=item 3. It can be tricky getting L<WebGL|https://en.wikipedia.org/wiki/WebGL> to work with a L<Xvfb|https://en.wikipedia.org/wiki/Xvfb> instance.  L<glxinfo|https://dri.freedesktop.org/wiki/glxinfo/> can be useful to help debug issues in this case.  The mesa-dri-drivers rpm is also required for Redhat systems.

=back

With all those conditions being met, L<WebGL|https://en.wikipedia.org/wiki/WebGL> can be enabled like so;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( addons => 1, visible => 1 );
    if ($firefox->script(q[let c = document.createElement('canvas'); return c.getContext('webgl2') ? true : c.getContext('experimental-webgl') ? true : false;])) {
        $firefox->go("https://get.webgl.org/");
    } else {
        die "WebGL is not supported";
    }

=head1 FINDING ELEMENTS IN A SHADOW DOM

One aspect of L<Web Components|https://developer.mozilla.org/en-US/docs/Web/API/Web_components> is the L<shadow DOM|https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM>.  When you need to explore the structure of a L<custom element|https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_custom_elements>, you need to access it via the shadow DOM.  The following is an example of navigating the shadow DOM via a html file included in the test suite of this package.

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new();
    my $firefox_marionette_directory = Cwd::cwd();
    $firefox->go("file://$firefox_marionette_directory/t/data/elements.html");

    my $shadow_root = $firefox->find_tag('custom-square')->shadow_root();

    my $outer_div = $firefox->find_id('outer-div', $shadow_root);

So, this module is designed to allow you to navigate the shadow DOM using normal find methods, but you must get the shadow element's shadow root and use that as the root for the search into the shadow DOM.  An important caveat is that L<xpath|https://bugzilla.mozilla.org/show_bug.cgi?id=1822311> and L<tag name|https://bugzilla.mozilla.org/show_bug.cgi?id=1822321> strategies do not officially work yet (and also the class name and name strategies).  This module works around the tag name, class name and name deficiencies by using the matching L<css selector|/find_selector> search if the original search throws a recognisable exception.  Therefore these cases may be considered to be extremely experimental and subject to change when Firefox gets the "correct" functionality.

=head1 WEBSITES THAT BLOCK AUTOMATION

Marionette L<by design|https://developer.mozilla.org/en-US/docs/Web/API/Navigator/webdriver> allows web sites to detect that the browser is being automated.  Firefox L<no longer (since version 88)|https://bugzilla.mozilla.org/show_bug.cgi?id=1632821> allows you to disable this functionality while you are automating the browser.  If the web site you are trying to automate mysteriously fails when you are automating a workflow, but it works when you perform the workflow manually, you may be dealing with a web site that is hostile to automation.

At the very least, under these circumstances, it would be a good idea to be aware that there's an L<ongoing arms race|https://en.wikipedia.org/wiki/Web_scraping#Methods_to_prevent_web_scraping>, and potential L<legal issues|https://en.wikipedia.org/wiki/Web_scraping#Legal_issues> in this area.

=head1 X11 FORWARDING WITH FIREFOX

L<X11 Forwarding|https://man.openbsd.org/ssh#X> allows you to launch a L<remote firefox via ssh|/REMOTE-AUTOMATION-OF-FIREFOX-VIA-SSH> and have it visually appear in your local X11 desktop.  This can be accomplished with the following code;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(
                                             host    => 'remote-x11.example.org',
                                             visible => 'local',
                                             debug   => 1,
                                          );
    $firefox->go('https://metacpan.org');

Feedback is welcome on any odd X11 workarounds that might be required for different platforms.

=head1 UBUNTU AND FIREFOX DELIVERED VIA SNAP

L<Ubuntu 22.04 LTS|https://ubuntu.com/blog/ubuntu-22-04-lts-whats-new-linux-desktop> is packaging firefox as a L<snap|https://ubuntu.com/blog/whats-in-a-snap>.  This breaks the way that this module expects to be able to run, specifically, being able to setup a firefox profile in a systems temporary directory (/tmp or $TMPDIR in most Unix based systems) and allow the operating system to cleanup old directories caused by exceptions / network failures / etc.

Because of this design decision, attempting to run a snap version of firefox will simply result in firefox hanging, unable to read it's custom profile directory and hence unable to read the marionette port configuration entry.

Which would be workable except that; there does not appear to be _any_ way to detect that a snap firefox will run (/usr/bin/firefox is a bash shell which eventually runs the snap firefox), so there is no way to know (heuristics aside) if a normal firefox or a snap firefox will be launched by execing 'firefox'.

It seems the only way to fix this issue (as documented in more than a few websites) is;

=over

=item 1. sudo snap remove firefox

=item 2. sudo add-apt-repository -y ppa:mozillateam/ppa

=item 3. sudo apt update

=item 4. sudo apt install -t 'o=LP-PPA-mozillateam' firefox

=item 5. echo -e "Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 501" >/tmp/mozillateamppa

=item 6. sudo mv /tmp/mozillateamppa /etc/apt/preferences.d/mozillateamppa

=back

If anyone is aware of a reliable method to detect if a snap firefox is going to launch vs a normal firefox, I would love to know about it.

This technique is used in the L<setup-for-firefox-marionette-build.sh|setup-for-firefox-marionette-build.sh> script in this distribution.

=head1 DIAGNOSTICS

=over
 
=item C<< Failed to correctly setup the Firefox process >>

The module was unable to retrieve a session id and capabilities from Firefox when it requests a L<new_session|/new_session> as part of the initial setup of the connection to Firefox.

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

=item *
L<XML::Parser|XML::Parser>
 
=item *
L<Time::Local|Time::Local>
 
=back

=head1 INCOMPATIBILITIES

None reported.  Always interested in any products with marionette support that this module could be patched to work with.


=head1 BUGS AND LIMITATIONS

=head2 DOWNLOADING USING GO METHOD

When using the L<go|/go> method to go directly to a URL containing a downloadable file, Firefox can hang.  You can work around this by setting the L<page_load_strategy|Firefox::Marionette::Capabilities#page_load_strategy> to C<none> like below;

    #! /usr/bin/perl

    use strict;
    use warnings;
    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( page_load_strategy => 'none' ) );
    $firefox->go("https://github.com/david-dick/firefox-marionette/archive/refs/heads/master.zip");
    while(!$firefox->downloads()) { sleep 1 }
    while($firefox->downloading()) { sleep 1 }
    foreach my $path ($firefox->downloads()) {
        warn "$path has been downloaded";
    }
    $firefox->quit();

Also, check out the L<download|/download> method for an alternative.

=head2 MISSING METHODS

Currently the following Marionette methods have not been implemented;

=over
 
=item * WebDriver:SetScreenOrientation

=back

To report a bug, or view the current list of bugs, please visit L<https://github.com/david-dick/firefox-marionette/issues>

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

Thanks to L<Mike Kaply|https://mike.kaply.com/about/> for his L<post|https://mike.kaply.com/2015/02/10/installing-certificates-into-firefox/> describing importing certificates into Firefox.

Thanks also to the authors of the documentation in the following sources;

=over 4

=item * L<Marionette Protocol|https://firefox-source-docs.mozilla.org/testing/marionette/marionette/index.html>

=item * L<Marionette driver.js|https://hg.mozilla.org/mozilla-central/file/tip/remote/marionette/driver.sys.mjs>

=item * L<about:config|http://kb.mozillazine.org/About:config_entries>

=item * L<nsIPrefService interface|https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIPrefService>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2023, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

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
