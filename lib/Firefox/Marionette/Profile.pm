package Firefox::Marionette::Profile;

use strict;
use warnings;
use English qw( -no_match_vars );
use File::Spec();
use FileHandle();
use Fcntl();
use Config::INI::Reader();

BEGIN {
    if ( $OSNAME eq 'MSWin32' ) {
        require Win32;
    }
}
our $VERSION = '1.49';

sub ANY_PORT            { return 0 }
sub _GETPWUID_DIR_INDEX { return 7 }

sub profile_ini_directory {
    my $profile_ini_directory;
    if ( $OSNAME eq 'darwin' ) {
        my $home_directory =
          ( getpwuid $EFFECTIVE_USER_ID )[ _GETPWUID_DIR_INDEX() ];
        defined $home_directory
          or Firefox::Marionette::Exception->throw(
            "Failed to execute getpwuid for $OSNAME:$EXTENDED_OS_ERROR");
        $profile_ini_directory = File::Spec->catdir( $home_directory, 'Library',
            'Application Support', 'Firefox' );
    }
    elsif ( $OSNAME eq 'MSWin32' ) {
        $profile_ini_directory =
          File::Spec->catdir( Win32::GetFolderPath( Win32::CSIDL_APPDATA() ),
            'Mozilla', 'Firefox' );
    }
    elsif ( $OSNAME eq 'cygwin' ) {
        $profile_ini_directory =
          File::Spec->catdir( $ENV{APPDATA}, 'Mozilla', 'Firefox' );
    }
    else {
        my $home_directory =
          ( getpwuid $EFFECTIVE_USER_ID )[ _GETPWUID_DIR_INDEX() ];
        defined $home_directory
          or Firefox::Marionette::Exception->throw(
            "Failed to execute getpwuid for $OSNAME:$EXTENDED_OS_ERROR");
        $profile_ini_directory =
          File::Spec->catdir( $home_directory, '.mozilla', 'firefox' );
    }
    return $profile_ini_directory;
}

sub _read_ini_file {
    my ( $class, $profile_ini_directory, $handle ) = @_;
    if ( defined $handle ) {
        my $config = Config::INI::Reader->read_handle($handle);
        return $config;
    }
    else {
        if ( -d $profile_ini_directory ) {
            my $profile_ini_path =
              File::Spec->catfile( $profile_ini_directory, 'profiles.ini' );
            if ( -f $profile_ini_path ) {
                my $config = Config::INI::Reader->read_file($profile_ini_path);
                return $config;
            }
        }
    }
    return {};
}

sub default_name {
    my ($class)               = @_;
    my $profile_ini_directory = $class->profile_ini_directory();
    my $config                = $class->_read_ini_file($profile_ini_directory);
    foreach my $key (
        sort { $config->{$a}->{Name} cmp $config->{$b}->{Name} }
        grep { exists $config->{$_}->{Name} } keys %{$config}
      )
    {
        if ( ( $config->{$key}->{Default} ) && ( $config->{$key}->{Name} ) ) {
            return $config->{$key}->{Name};
        }
    }
    return;
}

sub names {
    my ($class)               = @_;
    my $profile_ini_directory = $class->profile_ini_directory();
    my $config                = $class->_read_ini_file($profile_ini_directory);
    my @names;
    foreach my $key (
        sort { $config->{$a}->{Name} cmp $config->{$b}->{Name} }
        grep { exists $config->{$_}->{Name} } keys %{$config}
      )
    {
        if ( defined $config->{$key}->{Name} ) {
            push @names, $config->{$key}->{Name};
        }
    }
    return @names;
}

sub path {
    my ( $class, $name ) = @_;
    if ( my $profile_directory = $class->directory($name) ) {
        return File::Spec->catfile( $profile_directory, 'prefs.js' );
    }
    return;
}

sub _parse_config_for_path {
    my ( $class, $name, $config, $profile_ini_directory ) = @_;
    my @path;
    my $first_key;
    foreach my $key ( sort { $a cmp $b } keys %{$config} ) {
        if ( ( !defined $first_key ) && ( defined $config->{$key}->{Name} ) ) {
            $first_key = $key;
        }
        my $selected;
        if (   ( defined $name )
            && ( defined $config->{$key}->{Name} )
            && ( $name eq $config->{$key}->{Name} ) )
        {
            $selected = 1;
        }
        elsif ( ( !defined $name ) && ( $config->{$key}->{Default} ) ) {
            $selected = 1;
        }
        if ($selected) {
            if ( $config->{$key}->{IsRelative} ) {
                @path = ( $profile_ini_directory, $config->{$key}->{Path} );
            }
            elsif ( $config->{$key}->{Path} ) {
                @path = ( $config->{$key}->{Path} );
            }
            else {
                @path = ( $profile_ini_directory, $config->{$key}->{Default} );
            }
        }
    }
    if ( ( !@path ) && ( !defined $name ) && ( defined $first_key ) ) {
        if ( $config->{$first_key}->{IsRelative} ) {
            @path = ( $profile_ini_directory, $config->{$first_key}->{Path} );
        }
        else {
            @path = ( $config->{$first_key}->{Path} );
        }
    }
    return @path;
}

sub directory {
    my ( $class, $name, $config, $profile_ini_directory, $remote_address ) = @_;
    if ( !$name ) {
        Firefox::Marionette::Exception->throw(
            'No profile name has been supplied');
    }
    $remote_address = $remote_address ? "$remote_address:" : q[];
    $profile_ini_directory =
        $profile_ini_directory
      ? $profile_ini_directory
      : $class->profile_ini_directory();
    $config =
      $config ? $config : $class->_read_ini_file($profile_ini_directory);
    my @path =
      $class->_parse_config_for_path( $name, $config, $profile_ini_directory );
    if ( !@path ) {
        Firefox::Marionette::Exception->throw(
"Failed to find Firefox profile for '$name' in $remote_address$profile_ini_directory"
        );
    }
    if (wantarray) {
        return @path;
    }
    else {
        my $path = File::Spec->catfile(@path);
        return $path;
    }
}

sub existing {
    my ( $class, $name ) = @_;
    my $path = $class->path($name);
    if ( ($path) && ( -f $path ) ) {
        return $class->parse($path);
    }
    else {
        return;
    }
}

sub new {
    my ( $class, %parameters ) = @_;
    my $profile = bless { comments => q[], keys => {} }, $class;
    $profile->set_value( 'bookmarks.initialized.pref', 'true', 0 );
    $profile->set_value( 'browser.bookmarks.restore_default_bookmarks',
        'false', 0 );
    $profile->set_value( 'browser.download.useDownloadDir', 'true', 0 );
    $profile->set_value( 'browser.download.folderList',     2,      0 )
      ;    # the last folder specified for a download
    $profile->set_value( 'browser.places.importBookmarksHTML',  'true',  0 );
    $profile->set_value( 'browser.reader.detectedFirstArticle', 'true',  0 );
    $profile->set_value( 'browser.region.network.scan',         'false', 0 );
    $profile->set_value( 'browser.region.network.url',          q[],     0 );
    $profile->set_value( 'browser.region.update.enabled',       'false', 0 );
    $profile->set_value( 'browser.shell.checkDefaultBrowser',   'false', 0 );
    $profile->set_value( 'browser.showQuitWarning',             'false', 0 );
    $profile->set_value( 'browser.startup.homepage', 'about:blank',      1 );
    $profile->set_value( 'browser.startup.homepage_override.mstone',
        'ignore', 1 );
    $profile->set_value( 'browser.startup.page',                  '0',      0 );
    $profile->set_value( 'browser.tabs.warnOnClose',              'false',  0 );
    $profile->set_value( 'browser.toolbars.bookmarks.visibility', 'never',  1 );
    $profile->set_value( 'browser.topsites.contile.enabled',      'false',  0 );
    $profile->set_value( 'browser.warnOnQuit',                    'false',  0 );
    $profile->set_value( 'datareporting.policy.firstRunURL',      q[],      1 );
    $profile->set_value( 'devtools.jsonview.enabled',             'false',  0 );
    $profile->set_value( 'devtools.netmonitor.persistlog',        'true',   0 );
    $profile->set_value( 'devtools.toolbox.host',                 'window', 1 );
    $profile->set_value( 'dom.disable_open_click_delay',          0,        0 );
    $profile->set_value( 'extensions.installDistroAddons',        'false',  0 );
    $profile->set_value( 'focusmanager.testmode',                 'true',   0 );
    $profile->set_value( 'marionette.port',                       ANY_PORT() );
    $profile->set_value( 'network.http.prompt-temp-redirect',     'false', 0 );
    $profile->set_value( 'network.http.request.max-start-delay',  '0',     0 );
    $profile->set_value( 'network.proxy.socks_remote_dns',        'true',  0 );
    $profile->set_value( 'security.osclientcerts.autoload',       'true',  0 );
    $profile->set_value( 'security.webauth.webauthn_enable_usbtoken',
        'false', 0 );
    $profile->set_value( 'security.webauth.webauthn_enable_softtoken',
        'true', 0 );
    $profile->set_value( 'signon.autofillForms',         'false',       0 );
    $profile->set_value( 'signon.autologin.proxy',       'true',        0 );
    $profile->set_value( 'signon.rememberSignons',       'false',       0 );
    $profile->set_value( 'startup.homepage_welcome_url', 'about:blank', 1 );
    $profile->set_value( 'startup.homepage_welcome_url.additional',
        'about:blank', 1 );

    if ( !$parameters{seer} ) {
        $profile->set_value( 'browser.urlbar.speculativeConnect.enable',
            'false', 0 );
        $profile->set_value( 'network.dns.disablePrefetch', 'true', 0 );
        $profile->set_value( 'network.http.speculative-parallel-limit', '0',
            0 );
        $profile->set_value( 'network.prefetch-next', 'false', 0 );
    }
    if ( !$parameters{chatty} ) {
        $profile->set_value( 'app.normandy.enabled',          'false',   0 );
        $profile->set_value( 'app.update.auto',               'false',   0 );
        $profile->set_value( 'app.update.doorhanger',         'false',   0 );
        $profile->set_value( 'app.update.enabled',            'false',   0 );
        $profile->set_value( 'app.update.checkInstallTime',   'false',   0 );
        $profile->set_value( 'app.update.disabledForTesting', 'true',    0 );
        $profile->set_value( 'app.update.idletime',           '1314000', 0 );
        $profile->set_value(
            'app.update.lastUpdateDate.background-update-timer',
            time, 0 );
        $profile->set_value( 'app.update.staging.enabled', 'false',      0 );
        $profile->set_value( 'app.update.timer',           '131400000',  0 );
        $profile->set_value( 'beacon.enabled',             'false',      0 );
        $profile->set_value( 'browser.aboutConfig.showWarning', 'false', 0 );
        $profile->set_value( 'browser.aboutHomeSnippets.updateUrl', q[], 1 );
        $profile->set_value( 'browser.beacon.enabled',          'false', 0 );
        $profile->set_value( 'browser.casting.enabled',         'false', 0 );
        $profile->set_value( 'browser.chrome.favicons',         'false', 0 );
        $profile->set_value( 'browser.chrome.site_icons',       'false', 0 );
        $profile->set_value( 'browser.dom.window.dump.enabled', 'false', 0 );
        $profile->set_value( 'browser.download.panel.shown',    'true',  0 );
        $profile->set_value( 'browser.EULA.override',           'true',  0 );
        $profile->set_value(
            'browser.newtabpage.activity-stream.feeds.section.highlights',
            'false', 0 );
        $profile->set_value(
'browser.newtabpage.activity-stream.feeds.section.topstories.options',
            q[{}], 1
        );
        $profile->set_value(
            'browser.newtabpage.activity-stream.feeds.snippets',
            'false', 0 );
        $profile->set_value(
            'browser.newtabpage.activity-stream.feeds.topsites',
            'false', 0 );
        $profile->set_value( 'browser.newtabpage.introShown', 'true',  0 );
        $profile->set_value( 'browser.offline',               'false', 0 );
        $profile->set_value( 'browser.pagethumbnails.capturing_disabled',
            'false', 0 );
        $profile->set_value( 'browser.reader.detectedFirstArticle', 'true', 0 );
        $profile->set_value( 'browser.safebrowsing.blockedURIs.enabled',
            'false', 0 );
        $profile->set_value( 'browser.safebrowsing.downloads.enabled',
            'false', 0 );
        $profile->set_value( 'browser.safebrowsing.downloads.remote.enabled',
            'false', 0 );
        $profile->set_value( 'browser.safebrowsing.enabled', 'false', 0 );
        $profile->set_value( 'browser.safebrowsing.forbiddenURIs.enabled',
            'false', 0 );
        $profile->set_value( 'browser.safebrowsing.malware.enabled',
            'false', 0 );
        $profile->set_value( 'browser.safebrowsing.phishing.enabled',
            'false', 0 );
        $profile->set_value( 'browser.safebrowsing.provider.google.lists',
            q[], 1 );
        $profile->set_value( 'browser.search.geoip.url', q[],     1 );
        $profile->set_value( 'browser.search.update',    'false', 0 );
        $profile->set_value( 'browser.selfsupport',      'false', 0 );
        $profile->set_value( 'browser.send_pings',       'false', 0 );
        $profile->set_value( 'browser.sessionstore.resume_from_crash',
            'false', 0 );
        $profile->set_value( 'browser.shell.shortcutFavicons',     'false', 0 );
        $profile->set_value( 'browser.snippets.enabled',           'false', 0 );
        $profile->set_value( 'browser.snippets.syncPromo.enabled', 'false', 0 );
        $profile->set_value( 'browser.snippets.firstrunHomepage.enabled',
            'false', 0 );
        $profile->set_value( 'browser.tabs.animate', 'false', 0 );
        $profile->set_value( 'browser.tabs.closeWindowWithLastTab', 'false',
            0 );
        $profile->set_value( 'browser.tabs.disableBackgroundZombification',
            'false', 0 );
        $profile->set_value( 'browser.tabs.warnOnCloseOtherTabs', 'false', 0 );
        $profile->set_value( 'browser.tabs.warnOnOpen',           'false', 0 );
        $profile->set_value( 'browser.usedOnWindows10.introURL',  q[],     1 );
        $profile->set_value( 'browser.uitour.enabled',            'false', 0 );
        $profile->set_value( 'datareporting.healthreport.uploadEnabled',
            'false', 0 );
        $profile->set_value( 'dom.battery.enabled',          'false', 0 );
        $profile->set_value( 'extensions.blocklist.enabled', 'false', 0 );
        $profile->set_value( 'extensions.formautofill.addresses.enabled',
            'false', 0 );
        $profile->set_value( 'extensions.formautofill.creditCards.enabled',
            'false', 0 );
        $profile->set_value( 'extensions.pocket.enabled',          'false', 0 );
        $profile->set_value( 'extensions.pocket.site',             q[],     1 );
        $profile->set_value( 'extensions.getAddons.cache.enabled', 'false', 0 );
        $profile->set_value( 'extensions.update.autoUpdateDefault', 'false',
            0 );
        $profile->set_value( 'extensions.update.enabled',         'false', 0 );
        $profile->set_value( 'extensions.update.notifyUser',      'false', 0 );
        $profile->set_value( 'general.useragent.updates.enabled', 'false', 0 );
        $profile->set_value( 'geo.enabled',                       'false', 0 );
        $profile->set_value( 'geo.provider.testing',              'true',  0 );
        $profile->set_value( 'geo.wifi.scan',                     'false', 0 );
        $profile->set_value( 'media.gmp-gmpopenh264.autoupdate',  'false', 0 );
        $profile->set_value( 'media.gmp-gmpopenh264.enabled',     'false', 0 );
        $profile->set_value( 'media.gmp-manager.cert.checkAttributes',
            'false', 0 );
        $profile->set_value( 'media.gmp-manager.cert.requireBuiltIn',
            'false', 0 );
        $profile->set_value( 'media.gmp-provider.enabled', 'false', 0 );
        $profile->set_value( 'media.navigator.enabled',    'false', 0 );
        $profile->set_value( 'network.captive-portal-service.enabled',
            'false', 0 );
        $profile->set_value( 'network.cookie.lifetimePolicy',       '2',    0 );
        $profile->set_value( 'privacy.clearOnShutdown.downloads',   'true', 0 );
        $profile->set_value( 'privacy.clearOnShutdown.formdata',    'true', 0 );
        $profile->set_value( 'privacy.clearOnShutdown.history',     'true', 0 );
        $profile->set_value( 'privacy.clearOnShutdown.offlineApps', 'true', 0 );
        $profile->set_value( 'privacy.clearOnShutdown.openWindows', 'true', 0 );
        $profile->set_value( 'privacy.clearOnShutdown.sessions',    'true', 0 );
        $profile->set_value( 'privacy.clearOnShutdown.siteSettings', 'true',
            0 );
        $profile->set_value( 'privacy.donottrackheader.enabled',   'true', 0 );
        $profile->set_value( 'privacy.trackingprotection.enabled', 'true', 0 );
        $profile->set_value(
            'privacy.trackingprotection.fingerprinting.enabled',
            'true', 0 );
        $profile->set_value( 'privacy.trackingprotection.pbmode.enabled',
            'false', 0 );
        $profile->set_value( 'profile.enable_profile_migration', 'false', 0 );
        $profile->set_value( 'services.sync.prefs.sync.browser.search.update',
            'false', 0 );
        $profile->set_value(
'services.sync.prefs.sync.privacy.trackingprotection.cryptomining.enabled',
            'false', 0
        );
        $profile->set_value(
            'services.sync.prefs.sync.privacy.trackingprotection.enabled',
            'false', 0 );
        $profile->set_value(
'services.sync.prefs.sync.privacy.trackingprotection.fingerprinting.enabled',
            'false', 0
        );
        $profile->set_value(
'services.sync.prefs.sync.privacy.trackingprotection.pbmode.enabled',
            'false', 0
        );
        $profile->set_value( 'signon.rememberSignons', 'false', 0 );
        $profile->set_value( 'signon.management.page.breach-alerts.enabled',
            'false', 0 );
        $profile->set_value( 'toolkit.telemetry.archive.enabled', 'false', 0 );
        $profile->set_value( 'toolkit.telemetry.enabled',         'false', 0 );
        $profile->set_value( 'toolkit.telemetry.rejected',        'true',  0 );
        $profile->set_value( 'toolkit.telemetry.server',          q[],     1 );
        $profile->set_value( 'toolkit.telemetry.unified',         'false', 0 );
        $profile->set_value( 'toolkit.telemetry.unifiedIsOptIn',  'false', 0 );
        $profile->set_value( 'toolkit.telemetry.prompted',        '2',     0 );
        $profile->set_value( 'toolkit.telemetry.rejected',        'true',  0 );
        $profile->set_value( 'toolkit.telemetry.reportingpolicy.firstRun',
            'false', 0 );
        $profile->set_value( 'xpinstall.signatures.required', 'false', 0 );
    }
    return $profile;
}

sub download_directory {
    my ( $self, $new ) = @_;
    my $old;
    $self->set_value( 'browser.download.downloadDir',   $new, 1 );
    $self->set_value( 'browser.download.dir',           $new, 1 );
    $self->set_value( 'browser.download.lastDir',       $new, 1 );
    $self->set_value( 'browser.download.defaultFolder', $new, 1 );
    return $old;
}

sub save {
    my ( $self, $path ) = @_;
    my $temp_path = File::Temp::mktemp( $path . '.XXXXXXXXXXX' );
    my $handle =
      FileHandle->new( $temp_path,
        Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
        Fcntl::S_IRWXU() )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$temp_path' for writing:$EXTENDED_OS_ERROR");
    $handle->write( $self->as_string() )
      or Firefox::Marionette::Exception->throw(
        "Failed to write to '$temp_path':$EXTENDED_OS_ERROR");
    $handle->close()
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$temp_path':$EXTENDED_OS_ERROR");
    rename $temp_path, $path
      or Firefox::Marionette::Exception->throw(
        "Failed to rename '$temp_path' to '$path':$EXTENDED_OS_ERROR");
    return;
}

sub as_string {
    my ($self) = @_;
    my $string = q[];
    foreach my $key ( sort { $a cmp $b } keys %{ $self->{keys} } ) {
        my $value = $self->{keys}->{$key}->{value};
        if (
            ( defined $value )
            && (   ( $value eq 'true' )
                || ( $value eq 'false' )
                || ( $value =~ /^\d{1,6}$/smx ) )
          )
        {
            $string .= "user_pref(\"$key\", $value);\n";
        }
        elsif ( defined $value ) {
            $value =~ s/\\/\\\\/smxg;
            $value =~ s/"/\\"/smxg;
            $string .= "user_pref(\"$key\", \"$value\");\n";
        }
    }
    return $string;
}

sub set_value {
    my ( $self, $name, $value ) = @_;
    $self->{keys}->{$name} = { value => $value };
    return $self;
}

sub clear_value {
    my ( $self, $name ) = @_;
    return delete $self->{keys}->{$name};
}

sub get_value {
    my ( $self, $name ) = @_;
    return $self->{keys}->{$name}->{value};
}

sub parse {
    my ( $proto, $path ) = @_;
    my $handle = FileHandle->new( $path, Fcntl::O_RDONLY() )
      or Firefox::Marionette::Exception->throw(
        "Failed to open '$path' for reading:$EXTENDED_OS_ERROR");
    my $self = $proto->parse_by_handle($handle);
    close $handle
      or Firefox::Marionette::Exception->throw(
        "Failed to close '$path':$EXTENDED_OS_ERROR");
    return $self;
}

sub parse_by_handle {
    my ( $proto, $handle ) = @_;
    my $self = ref $proto ? $proto : bless {}, $proto;
    $self->{comments} = q[];
    $self->{keys}     = {};
    while ( my $line = <$handle> ) {
        chomp $line;
        if (
            ( ( scalar keys %{ $self->{keys} } ) == 0 )
            && (   ( $line !~ /\S/smx )
                || ( $line =~ /^[#]/smx )
                || ( $line =~ /^\/[*]/smx )
                || ( $line =~ /^\/\//smx )
                || ( $line =~ /^\s+[*]/smx ) )
          )
        {
            $self->{comments} .= $line;
        }
        elsif ( $line =~ /^user_pref[(]"([^"]+)",[ ](["]?)(.+)\2?[)];\s*$/smx )
        {
            my ( $name, $quoted, $value ) = ( $1, $2, $3 );
            $value =~ s/$quoted$//smx;
            $value =~ s/\\$quoted/$quoted/smxg;
            $self->{keys}->{$name} = { value => $value };
        }
        else {
            Firefox::Marionette::Exception->throw("Failed to parse '$line'");
        }
    }
    return $self;

}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Profile - Represents a prefs.js Firefox Profile

=head1 VERSION

Version 1.49

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $profile = Firefox::Marionette::Profile->new();

    $profile->set_value('browser.startup.homepage', 'https://duckduckgo.com');

    my $firefox = Firefox::Marionette->new(profile => $profile);
	
    $firefox->quit();
	
    foreach my $profile_name (Firefox::Marionette::Profile->names()) {
        # start firefox using a specific existing profile
        $firefox = Firefox::Marionette->new(profile_name => $profile_name);
        $firefox->quit();

        # OR start a new browser with a copy of a specific existing profile

        $profile = Firefox::Marionette::Profile->existing($profile_name);
        $firefox = Firefox::Marionette->new(profile => $profile);
        $firefox->quit();
    }

=head1 DESCRIPTION

This module handles the implementation of a C<prefs.js> Firefox Profile

=head1 CONSTANTS

=head2 ANY_PORT

returns the port number for Firefox to listen on any port (0).

=head1 SUBROUTINES/METHODS

=head2 new

returns a new L<profile|Firefox::Marionette::Profile>.

=head2 names

returns a list of existing profile names that this module can discover on the filesystem.

=head2 default_name

returns the default profile name.

=head2 directory

accepts a profile name and returns the directory path that contains the C<prefs.js> file.

=head2 download_directory

accepts a directory path that will contain downloaded files.  Returns the previous value for download directory.

=head2 existing

accepts a profile name and returns a L<profile|Firefox::Marionette::Profile> object for that specified profile name.

=head2 parse

accepts a path as the parameter.  This path should be to a C<prefs.js> file.  Parses the file and returns it as a L<profile|Firefox::Marionette::Profile>.

=head2 parse_by_handle

accepts a filehandle as the parameter to a C<prefs.js> file.  Parses the file and returns it as a L<profile|Firefox::Marionette::Profile>.

=head2 path

accepts a profile name and returns the corresponding path to the C<prefs.js> file.

=head2 profile_ini_directory

returns the base directory for profiles.

=head2 save

accepts a path as the parameter.  Saves the current profile to this location.

=head2 as_string

returns the contents of current profile as a string.

=head2 get_value

accepts a key name (such as C<browser.startup.homepage>) and returns the value of the key from the profile.

=head2 set_value

accepts a key name (such as C<browser.startup.homepage>) and a value (such as C<https://duckduckgo.com>) and sets this value in the profile.  It returns itself to aid in chaining methods

=head2 clear_value

accepts a key name (such as C<browser.startup.homepage>) and removes the key from the profile.  It returns the old value of the key (if any).

=head1 DIAGNOSTICS

=over
 
=item C<< Failed to execute getpwuid for %s:%s >>
 
The module was unable to to execute L<perlfunc/getpwuid>.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.

=item C<< Failed to open '%s' for writing:%s >>
 
The module was unable to open the named file.  Maybe your disk is full or the file permissions need to be changed?

=item C<< Failed to write to '%s':%s >>
 
The module was unable to write to the named file.  Maybe your disk is full?

=item C<< Failed to close '%s':%s >>
 
The module was unable to close a handle to the named file.  Something is seriously wrong with your environment.

=item C<< Failed to rename '%s' to '%s':%s >>
 
The module was unable to rename the named file to the second file.  Something is seriously wrong with your environment.

=item C<< Failed to open '%s' for reading:%s >>
 
The module was unable to open the named file.  Maybe your disk is full or the file permissions need to be changed?

=item C<< Failed to parse line '%s' >>
 
The module was unable to parse the line for a Firefox prefs.js configuration.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.

=back

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Profile requires no configuration files or environment variables.

=head1 DEPENDENCIES

Firefox::Marionette::Profile requires the following non-core Perl modules
 
=over
 
=item *
L<Config::INI::Reader|Config::INI::Reader>
 
=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

To report a bug, or view the current list of bugs, please visit L<https://github.com/david-dick/firefox-marionette/issues>

=head1 AUTHOR

David Dick  C<< <ddick@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2023, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic/perlartistic>.

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
