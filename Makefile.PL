use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Spec();
use Fcntl();
use English qw( -no_match_vars );

sub _win32_registry_query_key {
    my (%parameters) = @_;
    my $binary = 'reg';
    my @parameters =
      ( 'query', q["] . ( join q[\\], @{ $parameters{subkey} } ) . q["] );
    if ( $parameters{name} ) {
        push @parameters, ( '/v', q["] . $parameters{name} . q["] );
    }
    my @values;
    my $command   = join q[ ], $binary, @parameters;
    my $reg_query = `$command 2>nul`;
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
    my ($path) = @_;
    sysopen my $handle, $path, Fcntl::O_RDONLY();
    my $value;
    if ( defined $handle ) {
        no warnings;
        while ( read $handle, my $buffer, 1 ) {
            $value .= $buffer;
        }
        use warnings;
        if ( defined $value ) {
            $value =~ s/\0$//smx;
        }
    }
    return $value;
}

if ( ( $OSNAME eq 'MSWin32' ) || ( $OSNAME eq 'cygwin' ) ) {
}
elsif ( $EFFECTIVE_USER_ID == 0 ) {    # see RT#131304
    my $current = $ENV{HOME};
    my $correct = ( getpwuid $EFFECTIVE_USER_ID )[7];
    if ( $current eq $correct ) {
    }
    else {
        $ENV{HOME} = $correct;
        warn
"Running as root.  Resetting HOME environment variable from $current to $ENV{HOME}\n";
    }
    if ( exists $ENV{XAUTHORITY} ) {    # see GH#1
        delete $ENV{XAUTHORITY};
        warn "Running as root.  Deleting the XAUTHORITY environment variable\n";
    }
}

my @possibles = qw(firefox waterfox basilisk);
my $dev_null  = File::Spec->devnull();

sub last_desperate_search {
    if ( ( $OSNAME eq 'MSWin32' ) ) {
        foreach my $possible (@possibles) {
            warn "Checking for $possible in Path:"
              . `"$possible.exe" -version 2>$dev_null` . "\n";
        }
    }
    elsif ( ( $OSNAME eq 'darwin' ) or ( $OSNAME eq 'cygwin' ) ) {
        foreach my $possible (@possibles) {
            warn "Checking for $possible in PATH:"
              . `$possible -version $dev_null` . "\n";
        }
    }
    my $glob_path = '/usr/share/applications/firefox*.desktop';
    foreach my $path ( glob $glob_path ) {
        warn
`$EXECUTABLE_NAME -nle 'print "\$ARGV:\$_" if (/(Exec|^\\[)/);' $path`;
    }
    return;
}

my $binary;    #                      = 'firefox';
my $suffix =
  ( ( $OSNAME eq 'MSWin32' ) || ( $OSNAME eq 'cygwin' ) ) ? '.exe' : q[];
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
my %_known_win32_organisations = (
    'Mozilla Firefox'           => 'Mozilla',
    'Mozilla Firefox ESR'       => 'Mozilla',
    'Firefox Developer Edition' => 'Mozilla',
    Nightly                     => 'Mozilla',
    'Waterfox'                  => 'Waterfox',
    'Waterfox Current'          => 'Waterfox',
    'Waterfox Classic'          => 'Waterfox',
    Basilisk                    => 'Mozilla',
    'Pale Moon'                 => 'Mozilla',
);
my $version_regex = qr/(\d+)[.](\d+(?:\w\d+)?)(?:[.](\d+))?/smx;
my $version_string;
if ( $OSNAME eq 'MSWin32' ) {
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
            my $organisation = $_known_win32_organisations{$name};
            my ($version) = _win32_registry_query_key(
                subkey => [ 'HKLM', @{$root_subkey}, $organisation, $name ],
                name   => 'CurrentVersion'
            );
            if ( !defined $version ) {
                next ROOT_SUBKEY;
            }
            my ($initial_version) = _win32_registry_query_key(
                subkey => [ 'HKLM', @{$root_subkey}, $organisation, $name ],
                name   => q[]    # (Default) value
            );
            my $name_for_path_to_exe = $name;
            $name_for_path_to_exe =~ s/[ ]ESR//smx;
            my ($path) = _win32_registry_query_key(
                subkey => [
                    'HKLM',        @{$root_subkey},
                    $organisation, $name_for_path_to_exe,
                    $version,      'Main'
                ],
                name => 'PathToExe'
            );
            if ( ( defined $path ) && ( -e $path ) ) {
                $binary = $path;
                last NAME;
            }
        }
    }
}
elsif ( $OSNAME eq 'darwin' ) {
    foreach my $path (
        '/Applications/Firefox.app/Contents/MacOS/firefox',
        '/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox',
        '/Applications/Firefox Nightly.app/Contents/MacOS/firefox',
        '/Applications/Waterfox Current.app/Contents/MacOS/waterfox',
      )
    {
        if ( -e $path ) {
            $binary = $path;
        }
    }
}
elsif ( $OSNAME eq 'cygwin' ) {
  NAME: foreach my $name (
        sort {
            $known_win32_preferred_names{$a}
              <=> $known_win32_preferred_names{$b}
        } keys %known_win32_preferred_names
      )
    {
      ROOT_SUBKEY:
        foreach my $root_subkey (qw(SOFTWARE SOFTWARE/WOW6432Node)) {
            my $organisation = $_known_win32_organisations{$name};
            my $version =
              _cygwin_reg_query_value( '/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name
                  . '/CurrentVersion' );
            if ( !defined $version ) {
                next ROOT_SUBKEY;
            }
            my $initial_version =
              _cygwin_reg_query_value( '/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name
                  . q[/@] );    # (Default) value
            my $name_for_path_to_exe = $name;
            $name_for_path_to_exe =~ s/[ ]ESR//smx;
            my $path =
              _cygwin_reg_query_value( '/proc/registry/HKEY_LOCAL_MACHINE/'
                  . $root_subkey . q[/]
                  . $organisation . q[/]
                  . $name_for_path_to_exe . q[/]
                  . $version
                  . '/Main/PathToExe' );
            if (   ( defined $path )
                && ( -e $path )
                && ( $initial_version =~ /^$version_regex$/smx ) )
            {
                $binary         = `cygpath -s -m "$path"`;
                $version_string = "$name $initial_version";
                $version_string =~ s/[ ]ESR//smx;
                last NAME;
            }
        }
    }
}
if ( !defined $binary ) {
  POSSIBLE: foreach my $possible (@possibles) {
        foreach my $path (
            split /$Config::Config{path_sep}/smx,
            defined $ENV{PATH} ? $ENV{PATH} : $ENV{Path}
          )
        {
            if ( -e "$path/$possible$suffix" ) {
                $binary = "$path/$possible";
                last POSSIBLE;
            }
        }
    }
}
if ( ( !defined $version_string ) && ( defined $binary ) ) {
    my $ini_path = $binary;
    $ini_path =~ s/(firefox|waterfox)(?:[.]exe)?$/application.ini/smx;
    if ( open my $ini_handle, '<', $ini_path ) {
        my $vendor;
        my $name;
        while ( my $line = <$ini_handle> ) {
            chomp $line;
            if ( $line =~ /^Vendor=(.*)$/smx ) {
                ($vendor) = ($1);
            }
            elsif ( $line =~ /^Name=(.*)$/smx ) {
                ($name) = ($1);
            }
            elsif ( $line =~ /^Version=($version_regex)$/smx ) {
                $version_string = "$vendor $name $1\n";
                warn "Determining version string from $ini_path\n";
            }
        }
    }
}
if ( ( !defined $version_string ) && ( defined $binary ) ) {
    $version_string = `"$binary" -version 2>$dev_null`;
}
my $major;
if ($version_string) {
    warn $version_string;
    if ( $version_string =~
/^(?:Mozilla[ ]Firefox|Firefox[ ]Developer[ ]Edition|Nightly)[ ](\d+)[.]\d+(?:a\d+)?([.]\d+)?\s*/smx
      )
    {
        ($major) = ($1);
        if ( $major < 31 ) {
            last_desperate_search();
            warn
"Please install a more recent version of Mozilla Firefox.  Current version is $major\n";
        }
    }
    elsif (
        $version_string =~ /^Waterfox[ ]/smx )
    {
    }
    elsif ( $version_string =~ /^Moonchild[ ]/smx ) {
    }
    else {
        last_desperate_search();
        die "Unable to parse $version_string\n";
    }
}
else {
    last_desperate_search();
    die "Mozilla Firefox cannot be discovered in $ENV{PATH}\n";
}
if ( $OSNAME eq 'linux' ) {
    local $ENV{PATH} = '/usr/bin:/bin:/usr/sbin:/sbin';
    warn "grep -r Mem /proc/meminfo\n";
    warn `grep -r Mem /proc/meminfo`;
    warn "ulimit -a | grep -i mem\n";
    warn `ulimit -a | grep -i mem`;
}
elsif ( $OSNAME =~ /bsd/smxi ) {
    local $ENV{PATH} = '/usr/bin:/bin:/usr/sbin:/sbin';
    warn "sysctl hw | egrep 'hw.(phys|user|real)'\n";
    warn `sysctl hw | egrep 'hw.(phys|user|real)'`;
    warn "ulimit -a | grep -i mem\n";
    warn `ulimit -a | grep -i mem`;
}
if ( ( $OSNAME eq 'linux' ) || ( $OSNAME eq 'freebsd' ) ) {
    local $ENV{PATH} = '/usr/bin:/bin:/usr/sbin:/sbin';
    my $virtual_memory = `ulimit -v 2>/dev/null`;
    if ( $CHILD_ERROR == 0 ) {
        chomp $virtual_memory;
        if ( $virtual_memory eq 'unlimited' ) {
        }
        elsif ( ( $OSNAME eq 'freebsd' ) && ( $virtual_memory < 1_800_000 ) ) {
            die
"$virtual_memory bytes of virtual memory is less than the required 1.8Gb to run test suite in $OSNAME\n";
        }
        elsif ( $virtual_memory < 2_400_000 ) {
            die
"$virtual_memory bytes of virtual memory is less than the required 2.4Gb to run test suite in $OSNAME\n";
        }
    }
}
if (   ( $OSNAME eq 'MSWin32' )
    || ( $OSNAME eq 'darwin' )
    || ( $OSNAME eq 'cygwin' ) )
{
}
elsif ( $ENV{DISPLAY} ) {
}
elsif ( $major > 55 ) {    # -headless is supported
}
else {
    `Xvfb -help 2>/dev/null >/dev/null`;
    if ( $CHILD_ERROR != 0 ) {
        die
"Unable to run tests when not in an X11 environment and Xvfb is not available.  Please install Xvfb\n";
    }
}

WriteMakefile(
    NAME          => 'Firefox::Marionette',
    AUTHOR        => 'David Dick <ddick@cpan.org>',
    VERSION_FROM  => 'lib/Firefox/Marionette.pm',
    ABSTRACT_FROM => 'lib/Firefox/Marionette.pm',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    (
        $ExtUtils::MakeMaker::VERSION >= 6.48
        ? ( 'MIN_PERL_VERSION' => '5.006' )
        : ()
    ),
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                url  => 'https://github.com/david-dick/firefox-marionette',
                web  => 'https://github.com/david-dick/firefox-marionette',
                type => 'git',
            },
            bugtracker => {
                web => 'https://github.com/david-dick/firefox-marionette/issues'
            },
        },
    },
    PL_FILES       => {},
    EXE_FILES      => [ 'ssh-auth-cmd-marionette', 'ca-bundle-for-firefox', ],
    BUILD_REQUIRES => {
        'Compress::Zlib'  => 0,
        'Cwd'             => 0,
        'Digest::SHA'     => 0,
        'File::HomeDir'   => 0,
        'HTTP::Daemon'    => 0,
        'HTTP::Status'    => 0,
        'IO::Socket::SSL' => 0,
        $] ge '5.010' ? ( 'PDF::API2' => 2.036 ) : (),
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Archive::Zip'        => 0,
        'base'                => 0,
        'Config'              => 0,
        'Config::INI::Reader' => 0,
        'DirHandle'           => 0,
        'Encode'              => 0,
        'English'             => 0,
        'Exporter'            => 0,
        'Fcntl'               => 0,
        'FileHandle'          => 0,
        'File::Find'          => 0,
        'File::Spec'          => 0,
        'File::Temp'          => 0,
        'HTTP::Response'      => 0,
        'IPC::Open3'          => 1.03,
        'JSON'                => 0,
        'MIME::Base64'        => 0,
        'overload'            => 0,
        'Pod::Simple::Text'   => 0,
        'POSIX'               => 0,
        'Socket'              => 0,
        'Text::CSV_XS'        => 0,
        'Term::ReadKey'       => 0,
        'Time::HiRes'         => 0,
        'URI'                 => 0,
        'URI::Escape'         => 0,
        (
            $OSNAME eq 'MSWin32'
            ? (
                'Win32'              => 0,
                'Win32::Process'     => 0,
                'Win32API::Registry' => 0,
              )
            : ()
        ),
        (
            (
                      $OSNAME ne 'MSWin32'
                  and $OSNAME ne 'darwin'
                  and $OSNAME ne 'cygwin'
            ) ? ( 'Crypt::URandom' => 0, )
            : ()
        ),
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Firefox-Marionette-*' },
);
