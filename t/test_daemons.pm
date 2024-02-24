package Test::File::Temp;

use strict;
use warnings;
use Carp();
use English qw( -no_match_vars );
use File::Spec();
use File::Temp();
use Crypt::PasswdMD5();

sub tmp_handle {
    my ( $class, $name ) = @_;
    my $handle = File::Temp->new(
        UNLINK   => 1,
        TEMPLATE => File::Spec->catfile(
            File::Spec->tmpdir(),
            'firefox_marionette_test_daemon_file_' . $name . '_XXXXXXXXXXX'
        )
      )
      or Carp::croak(
        "Failed to open temporary file for writing:$EXTENDED_OS_ERROR");
    fcntl $handle, Fcntl::F_SETFD(), 0
      or Carp::croak(
"Failed to clear the close-on-exec flag on a temporary file:$EXTENDED_OS_ERROR"
      );
    return $handle;
}

sub tmp_directory {
    my ( $class, $name ) = @_;
    my $directory = File::Temp->newdir(
        CLEANUP  => 1,
        TEMPLATE => File::Spec->catdir(
            File::Spec->tmpdir(),
            'firefox_marionette_test_daemon_directory_'
              . $name
              . '_XXXXXXXXXXX'
        )
      )
      or Carp::croak("Failed to create temporary directory:$EXTENDED_OS_ERROR");
    return $directory;
}

package Test::Binary::Available;

use strict;
use warnings;
use Carp();
use English qw( -no_match_vars );
use File::Spec();

sub find_binary {
    my ( $class, $binary ) = @_;
    foreach my $directory ( split /:/smx, $ENV{PATH} ) {
        my $possible_path = File::Spec->catfile( $directory, $binary );
        if ( -e $possible_path ) {
            return $possible_path;
        }
    }
    return $binary;
}

sub available {
    my ( $class, $binary, @arguments ) = @_;
    my $debug;
    if ( $ENV{FIREFOX_DEBUG} ) {
        $debug = $ENV{FIREFOX_DEBUG};
    }
    my $dev_null = File::Spec->devnull();
    if ( my $pid = fork ) {
        waitpid $pid, 0;
    }
    else {
        eval {
            open STDOUT, q[>], $dev_null
              or Carp::croak(
                "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR");
            if ( !$debug ) {
                open STDERR, q[>], $dev_null
                  or Carp::croak(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            open STDIN, q[<], $dev_null
              or Carp::croak(
                "Failed to redirect STDIN to $dev_null:$EXTENDED_OS_ERROR");
            exec {$binary} $binary, @arguments;
        } or do {

            # absolutely nothing, this is allowed to fail
        };
        exit 1;
    }
    return $CHILD_ERROR == 0 ? 1 : 0;
}

package Test::CA;

use strict;
use warnings;
use English qw( -no_match_vars );

@Test::CA::ISA = qw(Test::Binary::Available Test::File::Temp);

my $openssl_binary = 'openssl';

sub available {
    my ($class) = @_;
    return $class->SUPER::available( $openssl_binary, 'version' );
}

sub new {
    my ( $class, $key_size ) = @_;
    my $self = bless {}, $class;
    $self->{ca_directory} = $class->tmp_directory('ca');
    $self->{ca_cert_path} =
      File::Spec->catfile( $self->{ca_directory}->dirname(), 'ca.crt' );
    $self->{ca_cert_handle} = FileHandle->new(
        $self->{ca_cert_path},
        Fcntl::O_EXCL() | Fcntl::O_RDWR() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
      )
      or
      Carp::croak("Failed to create $self->{ca_cert_path}:$EXTENDED_OS_ERROR");
    $self->{ca_private_key_path} =
      File::Spec->catfile( $self->{ca_directory}->dirname(), 'ca.key' );
    $self->{ca_private_key_handle} =
      $class->new_key( $key_size, $self->{ca_private_key_path} );
    $self->{ca_serial_path} =
      File::Spec->catfile( $self->{ca_directory}->dirname(), 'ca.serial' );
    $self->{ca_serial_handle} = FileHandle->new(
        $self->{ca_serial_path},
        Fcntl::O_EXCL() | Fcntl::O_RDWR() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
      )
      or Carp::croak(
        "Failed to create $self->{ca_serial_path}:$EXTENDED_OS_ERROR");
    print { $self->{ca_serial_handle} } '01'
      or Carp::croak(
        "Failed to write to $self->{ca_serial_path}:$EXTENDED_OS_ERROR");
    close $self->{ca_serial_handle}
      or
      Carp::croak("Failed to close $self->{ca_serial_path}:$EXTENDED_OS_ERROR");
    $self->{ca_config_path} =
      File::Spec->catfile( $self->{ca_directory}->dirname(), 'ca.config' );
    $self->{ca_config_handle} = FileHandle->new(
        $self->{ca_config_path},
        Fcntl::O_EXCL() | Fcntl::O_RDWR() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
      )
      or Carp::croak(
        "Failed to create $self->{ca_config_path}:$EXTENDED_OS_ERROR");
    $self->{ca_config_handle}->print(<<"_CONFIG_");
[ req ]
distinguished_name     = req_distinguished_name
attributes             = req_attributes
prompt                 = no

[ req_distinguished_name ]
C                      = AU
ST                     = Victoria
L                      = Melbourne
O                      = David Dick
OU                     = CPAN
CN                     = Firefox::Marionette Root CA
emailAddress           = ddick\@cpan.org

[ req_attributes ]

[ signing_policy ]
countryName            = optional
stateOrProvinceName    = optional
localityName           = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

####################################################################
[ signing_req ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, keyEncipherment
prompt                 = no

_CONFIG_
    seek $self->{ca_config_handle}, 0, 0
      or Carp::croak(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    system {$openssl_binary} $openssl_binary, 'req', '-new', '-x509',
      '-config' => $self->{ca_config_path},
      '-days'   => 10,
      '-key'    => $self->{ca_private_key_path},
      '-out'    => $self->{ca_cert_path}
      and Carp::croak(
        "Failed to generate a CA root certificate:$EXTENDED_OS_ERROR");
    return $self;
}

sub config {
    my ($self) = @_;
    return $self->{ca_config_path};
}

sub serial {
    my ($self) = @_;
    return $self->{ca_serial_path};
}

sub cert {
    my ($self) = @_;
    return $self->{ca_cert_path};
}

sub key {
    my ($self) = @_;
    return $self->{ca_private_key_path};
}

sub new_cert {
    my ( $self, $key_path, $host_name, $path ) = @_;
    my $csr = $self->tmp_handle('csr');
    my $cert_handle;
    my $cert_path;
    if ($path) {
        $cert_handle = FileHandle->new(
            $path,
            Fcntl::O_EXCL() | Fcntl::O_RDWR() | Fcntl::O_CREAT(),
            Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
        ) or Carp::croak("Failed to create $path:$EXTENDED_OS_ERROR");
        $cert_path = $path;
    }
    else {
        $cert_handle = $self->tmp_handle('cert');
        $cert_path   = $cert_handle->filename();
    }
    system {$openssl_binary} $openssl_binary, 'req', '-new', '-sha256',
      '-config' => $self->config(),
      '-key'    => $key_path,
      '-subj'   =>
      "/C=AU/ST=Victoria/L=Melbourne/O=David Dick/OU=CPAN/CN=$host_name",
      '-out' => $csr->filename()
      and Carp::croak(
        "Failed to generate a certificate signing request:$EXTENDED_OS_ERROR");
    my $cert_extensions_handle = $self->tmp_handle('cert_ext');
    $cert_extensions_handle->print(<<"_CONFIG_");
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = \@alt_names
[alt_names]
IP.1 = $host_name
_CONFIG_
    seek $cert_extensions_handle, 0, 0
      or Carp::croak(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    system {$openssl_binary} $openssl_binary, 'x509', '-req',
      '-in'       => $csr->filename(),
      '-CA'       => $self->cert(),
      '-CAkey'    => $self->key(),
      '-extfile'  => $cert_extensions_handle->filename(),
      '-CAserial' => $self->serial(),
      '-sha256',
      '-days' => 10,
      '-out'  => $cert_path
      and Carp::croak("Failed to generate a certificate:$EXTENDED_OS_ERROR");
    my $ca_cert = FileHandle->new( $self->cert(), Fcntl::O_RDONLY() )
      or Carp::croak(
        'Failed to open ' . $self->cert() . " for reading:$EXTENDED_OS_ERROR" );

    seek $cert_handle, 0, Fcntl::SEEK_END()
      or Carp::croak(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    while ( my $line = <$ca_cert> ) {
        print {$cert_handle} $line
          or
          Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
    }
    seek $cert_handle, 0, Fcntl::SEEK_SET()
      or Carp::croak(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    return $cert_handle;
}

sub new_key {
    my ( $class, $size, $path ) = @_;
    my $private_key_handle;
    my $private_key_path;
    if ($path) {
        $private_key_handle = FileHandle->new(
            $path,
            Fcntl::O_EXCL() | Fcntl::O_RDWR() | Fcntl::O_CREAT(),
            Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
        ) or Carp::croak("Failed to create $path:$EXTENDED_OS_ERROR");
        $private_key_path = $path;
    }
    else {
        $private_key_handle = $class->tmp_handle('private_key');
        $private_key_path   = $private_key_handle->filename();
    }
    system {$openssl_binary} $openssl_binary, 'genrsa',
      '-out' => $private_key_path,
      $size
      and Carp::croak("Failed to generate a private key:$EXTENDED_OS_ERROR");
    return $private_key_handle;
}

package Test::Daemon;

use strict;
use warnings;
use Carp();
use Config;
use Socket();
use English qw( -no_match_vars );

@Test::Daemon::ISA = qw(Test::File::Temp);

sub CONVERT_TO_PROCESS_GROUP { return -1 }

my @sig_nums  = split q[ ], $Config{sig_num};
my @sig_names = split q[ ], $Config{sig_name};
my %signals_by_name;
my $idx = 0;
foreach my $sig_name (@sig_names) {
    $signals_by_name{$sig_name} = $sig_nums[$idx];
    $idx += 1;
}

sub new {
    my ( $class, %parameters ) = @_;
    my $debug = delete $parameters{debug};
    if ( $ENV{FIREFOX_DEBUG} ) {
        $debug = $ENV{FIREFOX_DEBUG};
    }
    my @arguments = @{ delete $parameters{arguments} };
    my %extra     = %parameters;
    my $self      = bless {
        binary    => $parameters{binary},
        arguments => \@arguments,
        port      => $parameters{port},
        debug     => $debug,
        %extra
    }, $class;
    $self->start();
    return $self;
}

sub debug {
    my ($self) = @_;
    return $self->{debug};
}

sub arguments {
    my ($self) = @_;
    return @{ $self->{arguments} };
}

sub address {
    my ($self) = @_;
    return $self->{listen};
}

sub wait_until_port_open {
    my ($self)     = @_;
    my $address    = $self->address();
    my $port       = $self->port();
    my $found_port = 0;
    while ( $found_port == 0 ) {
        socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0
          or Carp::croak("Failed to create a socket:$EXTENDED_OS_ERROR");
        my $sock_addr =
          Socket::pack_sockaddr_in( $port, Socket::inet_aton($address) );
        if ( connect $socket, $sock_addr ) {
            $found_port = $port;
        }
        else {
            my $kid = waitpid $self->pid(), POSIX::WNOHANG();
            if ( $kid == $self->pid() ) {
                Carp::croak('Server died while waiting for port to open');
            }
            sleep 1;
        }
        close $socket
          or Carp::croak("Failed to close test socket:$EXTENDED_OS_ERROR");
    }
    return;
}

sub directory {
    my ($self) = @_;
    return $self->{directory};
}

sub start {
    my ($self) = @_;
    my $dev_null = File::Spec->devnull();
    if ( $self->{pid} = fork ) {
        return $self->{pid};
    }
    elsif ( defined $self->{pid} ) {
        eval {
            local $SIG{INT}  = 'DEFAULT';
            local $SIG{TERM} = 'DEFAULT';
            if ( $self->{resetpg} ) {
                setpgrp $PID, 0
                  or Carp::croak(
                    "Failed to reset process group:$EXTENDED_OS_ERROR");
            }
            if ( my $directory = $self->directory() ) {
                chdir $directory
                  or
                  Carp::croak("Failed to chdir $directory:$EXTENDED_OS_ERROR");
            }
            open STDOUT, q[>], $dev_null
              or Carp::croak(
                "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR");
            if ( !$self->debug() ) {
                open STDERR, q[>], $dev_null
                  or Carp::croak(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            open STDIN, q[<], $dev_null
              or Carp::croak(
                "Failed to redirect STDIN to $dev_null:$EXTENDED_OS_ERROR");
            exec { $self->{binary} } $self->{binary}, $self->arguments()
              or Carp::croak(
                "Failed to exec '$self->{binary}':$EXTENDED_OS_ERROR");
        } or do {
            Carp::carp($EVAL_ERROR);
        };
        exit 1;
    }
    return;
}

sub pid {
    my ($self) = @_;
    return $self->{pid};
}

sub port {
    my ($self) = @_;
    return $self->{port};
}

sub new_port {
    socket my $socket, Socket::PF_INET(), Socket::SOCK_STREAM(), 0
      or Carp::croak("Failed to create a socket:$EXTENDED_OS_ERROR");
    bind $socket, Socket::sockaddr_in( 0, Socket::INADDR_LOOPBACK() )
      or Carp::croak("Failed to bind socket:$EXTENDED_OS_ERROR");
    my $port = ( Socket::sockaddr_in( getsockname $socket ) )[0];
    close $socket
      or Carp::croak("Failed to close random socket:$EXTENDED_OS_ERROR");
    return $port;
}

sub stop {
    my ($self) = @_;
    if ( my $pid = $self->{pid} ) {
        kill $signals_by_name{TERM}, $pid;
        waitpid $pid, 0;
        delete $self->{pid};
        return $CHILD_ERROR;
    }
    return;
}

sub stop_process_group {
    my ($self) = @_;
    if ( my $pid = $self->{pid} ) {
        my $pgrp = getpgrp $self->{pid}
          or Carp::croak(
            "Failed to get process group from $self->{pid}:$EXTENDED_OS_ERROR");
        $pgrp *= CONVERT_TO_PROCESS_GROUP();

        kill $signals_by_name{INT}, $pgrp;
        my $kid = waitpid $pgrp, 0;
        while ( $kid > 0 ) {
            sleep 1;
            $kid = waitpid $pgrp, POSIX::WNOHANG();
            if ( $kid > 0 ) {
                Carp::carp("Also gathered $kid");
            }
        }
        delete $self->{pid};
        return 0;
    }
    return;
}

sub DESTROY {
    my ($self) = @_;
    if ( $self->{resetpg} ) {
        $self->stop_process_group();
    }
    if ( my $pid = delete $self->{pid} ) {
        while ( kill 0, $pid ) {
            kill $signals_by_name{TERM}, $pid;
            sleep 1;
            waitpid $pid, POSIX::WNOHANG();
        }
    }
    return;
}

package Test::Daemon::Nginx;

use strict;
use warnings;
use Carp();
use Crypt::URandom();
use English qw( -no_match_vars );

@Test::Daemon::Nginx::ISA = qw(Test::Daemon Test::Binary::Available);

sub _RANDOM_STRING_LENGTH { return 50 }

my $nginx_binary = __PACKAGE__->find_binary('nginx');

sub available {
    my ($class) = @_;
    return $class->SUPER::available( $nginx_binary, '-v' );
}

sub write_passwd {
    my ( $class, $passwd_path, $username, $password ) = @_;
    if ( $username || $password ) {
        my $passwd_handle = FileHandle->new(
            $passwd_path,
            Fcntl::O_WRONLY() | Fcntl::O_EXCL() | Fcntl::O_CREAT(),
            Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
        ) or Carp::croak("Failed to open $passwd_path:$EXTENDED_OS_ERROR");
        my $encrypted_password = Crypt::PasswdMD5::unix_md5_crypt($password);
        print {$passwd_handle} "$username:$encrypted_password\n"
          or Carp::croak("Failed to write to $passwd_path:$EXTENDED_OS_ERROR");
        close $passwd_handle
          or Carp::croak("Failed to close $passwd_path:$EXTENDED_OS_ERROR");
    }
    return;
}

sub new {
    my ( $class, %parameters ) = @_;
    my $listen         = $parameters{listen};
    my $key_size       = $parameters{key_size};
    my $ca             = $parameters{ca};
    my $username       = $parameters{username};
    my $password       = $parameters{password};
    my $realm          = $parameters{realm};
    my $port           = $class->new_port();
    my $base_directory = $class->tmp_directory('nginx');
    my $passwd_path =
      File::Spec->catfile( $base_directory->dirname(), 'htpasswd' );

    $class->write_passwd( $passwd_path, $username, $password );
    my $key_path =
      File::Spec->catfile( $base_directory->dirname(), 'nginx.key' );
    my $certificate_path =
      File::Spec->catfile( $base_directory->dirname(), 'nginx.crt' );
    if ( $key_size && $ca ) {
        my $key_handle = $ca->new_key( $key_size, $key_path );
        my $certificate_handle =
          $ca->new_cert( $key_path, $listen, $certificate_path );
    }
    my $root_name = 'htdocs';
    my $root_directory =
      File::Spec->catfile( $base_directory->dirname(), $root_name );
    mkdir $root_directory, Fcntl::S_IRWXU()
      or Carp::croak("Failed to mkdir $root_directory:$EXTENDED_OS_ERROR");
    my $index_name      = 'index.txt';
    my $index_file_path = File::Spec->catfile( $root_directory, $index_name );
    my $index_handle    = FileHandle->new(
        $index_file_path,
        Fcntl::O_WRONLY() | Fcntl::O_EXCL() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
    ) or Carp::croak("Failed to open $index_file_path:$EXTENDED_OS_ERROR");
    my $random_string =
      MIME::Base64::encode_base64(
        Crypt::URandom::urandom( _RANDOM_STRING_LENGTH() ) );
    chomp $random_string;
    print {$index_handle} $random_string
      or Carp::croak("Failed to write to $index_file_path:$EXTENDED_OS_ERROR");
    close $index_handle
      or Carp::croak("Failed to close $index_file_path:$EXTENDED_OS_ERROR");
    my $pid_path =
      File::Spec->catfile( $base_directory->dirname(), 'nginx.pid' );
    my $pid_handle = FileHandle->new(
        $pid_path,
        Fcntl::O_WRONLY() | Fcntl::O_EXCL() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
    ) or Carp::croak("Failed to open $pid_path:$EXTENDED_OS_ERROR");
    my $config_path =
      File::Spec->catfile( $base_directory->dirname(), 'nginx.conf' );
    my $log_directory =
      File::Spec->catdir( $base_directory->dirname(), 'logs' );
    mkdir $log_directory, Fcntl::S_IRWXU()
      or Carp::croak("Failed to mkdir $log_directory:$EXTENDED_OS_ERROR");
    my $error_log_path = File::Spec->catfile( $log_directory, 'error.log' );
    my $access_log_path =
      File::Spec->catfile( $base_directory->dirname(), 'access.log' );
    my $config_handle = FileHandle->new(
        $config_path,
        Fcntl::O_WRONLY() | Fcntl::O_EXCL() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
    ) or Carp::croak("Failed to open $config_path:$EXTENDED_OS_ERROR");
    my %temp_directories;

    foreach my $name (
        qw(client_body_temp proxy_temp fastcgi_temp uwsgi_temp scgi_temp))
    {
        $temp_directories{$name} =
          File::Spec->catfile( $base_directory->dirname(), $name );
        mkdir $temp_directories{$name}, Fcntl::S_IRWXU()
          or Carp::croak(
            "Failed to mkdir $temp_directories{$name}:$EXTENDED_OS_ERROR");
    }
    print {$config_handle}
      <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
daemon off;
pid $pid_path;
error_log logs/error.log;

events {
    worker_connections 1024;
}

http {
    client_body_temp_path   $temp_directories{client_body_temp};
    proxy_temp_path         $temp_directories{proxy_temp};
    fastcgi_temp_path       $temp_directories{fastcgi_temp};
    uwsgi_temp_path         $temp_directories{uwsgi_temp};
    scgi_temp_path          $temp_directories{scgi_temp};
    access_log              logs/access.log;
    sendfile                on;
    tcp_nopush              on;
    tcp_nodelay             on;
    keepalive_timeout       65;
    types_hash_max_size     4096;

    default_type            text/plain;

    server  {
_NGINX_CONF_
    if ( $key_size && $ca ) {
        print {$config_handle}
          <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
        listen                     $listen:$port ssl;
_NGINX_CONF_
    }
    else {
        print {$config_handle}
          <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
        listen                     $listen:$port;
_NGINX_CONF_
    }
    print {$config_handle}
      <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
        server_name                default;
_NGINX_CONF_
    if ( $username || $password ) {
        print {$config_handle}
          <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
        auth_basic                 "$realm";
        auth_basic_user_file       $passwd_path;
_NGINX_CONF_
    }
    if ( $key_size && $ca ) {
        print {$config_handle}
          <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
        ssl_certificate            $certificate_path;
        ssl_certificate_key        $key_path;
        ssl_protocols              TLSv1.2;
        ssl_ciphers                ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:!AES128-SHA:!DES-CBC3-SHA:!MD5:!aNULL:!CAMELLIA:!PSK:!SRP;
        ssl_prefer_server_ciphers  on;
        ssl_session_cache          shared:SSL:10m;
        ssl_session_timeout        10m;
        ssl_stapling               off;
        ssl_stapling_verify        off;
        ssl_ecdh_curve             secp384r1;
_NGINX_CONF_
    }
    print {$config_handle}
      <<"_NGINX_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
        server_tokens              off;
        root                       $root_name;
        index                      $index_name;
    }
}
_NGINX_CONF_
    close $config_handle
      or Carp::croak("Failed to close $config_path:$EXTENDED_OS_ERROR");
    my $nginx = $class->SUPER::new(
        debug          => $parameters{debug},
        binary         => $nginx_binary,
        pid_handle     => $pid_handle,
        listen         => $listen,
        port           => $port,
        base_directory => $base_directory,
        content        => $random_string,
        arguments      => [ qw(-c), $config_path, qw(-p), $base_directory ]
    );
    return $nginx;
}

sub content {
    my ($self) = @_;
    return $self->{content};
}

package Test::Daemon::Squid;

use strict;
use warnings;
use Carp();
use English qw( -no_match_vars );

@Test::Daemon::Squid::ISA = qw(Test::Daemon Test::Binary::Available);

my $squid_binary = __PACKAGE__->find_binary('squid');

sub available {
    my ($class) = @_;
    return $class->SUPER::available( $squid_binary, '--version' );
}

sub find_basic_ncsa_auth {
    my $basic_ncsa_auth_path;
    foreach my $possible_path (
        '/usr/lib64/squid/basic_ncsa_auth',    # Redhat, Fedora
        '/usr/lib/squid/basic_ncsa_auth',      # Alpine Linux, Debian
        '/usr/local/libexec/squid/basic_ncsa_auth'
        ,                                      # FreeBSD, DragonflyBSD, OpenBSD
        '/usr/pkg/libexec/basic_ncsa_auth',    # NetBSD
      )
    {
        if ( -e $possible_path ) {
            $basic_ncsa_auth_path = $possible_path;
            last;
        }
    }
    return $basic_ncsa_auth_path;
}

sub new {
    my ( $class, %parameters ) = @_;
    my $listen               = $parameters{listen};
    my $username             = $parameters{username};
    my $password             = $parameters{password};
    my $realm                = $parameters{realm};
    my $key_size             = $parameters{key_size};
    my $ca                   = $parameters{ca};
    my $port                 = $class->new_port();
    my $base_directory       = $class->tmp_directory('squid');
    my $basic_ncsa_auth_path = $class->find_basic_ncsa_auth();
    my $passwd_path =
      File::Spec->catfile( $base_directory->dirname(), 'htpasswd' );

    if ( $username || $password ) {
        my $passwd_handle = FileHandle->new(
            $passwd_path,
            Fcntl::O_WRONLY() | Fcntl::O_EXCL() | Fcntl::O_CREAT(),
            Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
        ) or Carp::croak("Failed to open $passwd_path:$EXTENDED_OS_ERROR");
        my $encrypted_password = Crypt::PasswdMD5::unix_md5_crypt($password);
        print {$passwd_handle} "$username:$encrypted_password\n"
          or Carp::croak("Failed to write to $passwd_path:$EXTENDED_OS_ERROR");
        close $passwd_handle
          or Carp::croak("Failed to close $passwd_path:$EXTENDED_OS_ERROR");
    }
    my $key_path =
      File::Spec->catfile( $base_directory->dirname(), 'squid.key' );
    my $certificate_path =
      File::Spec->catfile( $base_directory->dirname(), 'squid.crt' );
    if ( $key_size && $ca ) {
        my $key_handle = $ca->new_key( $key_size, $key_path );
        my $certificate_handle =
          $ca->new_cert( $key_path, $listen, $certificate_path );
    }
    my $config_path =
      File::Spec->catfile( $base_directory->dirname(), 'squid.config' );
    my $config_handle = FileHandle->new(
        $config_path,
        Fcntl::O_WRONLY() | Fcntl::O_EXCL() | Fcntl::O_CREAT(),
        Fcntl::S_IRUSR() | Fcntl::S_IWUSR()
    ) or Carp::croak("Failed to open $config_path:$EXTENDED_OS_ERROR");
    if ( $username || $password ) {
        print {$config_handle}
          <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
auth_param basic program $basic_ncsa_auth_path $passwd_path
auth_param basic realm $realm
auth_param basic casesensitive on
acl Auth proxy_auth REQUIRED
_SQUID_CONF_
    }
    if ( $parameters{allow_ssl_port} ) {
        print {$config_handle}
          <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
acl SSL_ports port $parameters{allow_ssl_port}
http_access deny !SSL_ports
http_access deny CONNECT !SSL_ports
_SQUID_CONF_
    }
    elsif ( $parameters{allow_port} ) {
        print {$config_handle}
          <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
acl HTTP_ports port $parameters{allow_port}
http_access deny !HTTP_ports
http_access deny CONNECT HTTP_ports
_SQUID_CONF_
    }
    if ( $username || $password ) {
        print {$config_handle}
          <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
http_access deny !Auth
_SQUID_CONF_
    }
    print {$config_handle}
      <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
http_access allow localhost
_SQUID_CONF_
    if ( $key_size && $ca ) {
        print {$config_handle}
          <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
https_port $listen:$port tls-cert=$certificate_path tls-key=$key_path
_SQUID_CONF_
    }
    else {
        print {$config_handle}
          <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
http_port $listen:$port
_SQUID_CONF_
    }
    print {$config_handle}
      <<"_SQUID_CONF_" or Carp::croak("Failed to write to $config_path:$EXTENDED_OS_ERROR");
shutdown_lifetime 0 seconds
visible_hostname $listen
pid_filename none
access_log /dev/stderr
cache_log /dev/null
_SQUID_CONF_
    close $config_handle
      or Carp::croak("Failed to close $config_path:$EXTENDED_OS_ERROR");
    my $squid = $class->SUPER::new(
        debug          => $parameters{debug},
        binary         => $squid_binary,
        listen         => $listen,
        base_directory => $base_directory,
        port           => $port,
        arguments      => [ qw(-f), $config_path, qw(-N -d 3) ]
    );
    return $squid;
}

package Test::Daemon::SSH;

use strict;
use warnings;
use Carp();
use English qw( -no_match_vars );

@Test::Daemon::SSH::ISA = qw(Test::Daemon Test::Binary::Available);

sub _DEFAULT_PORT { return 22 }

my $sshd_binary = __PACKAGE__->find_binary('sshd');

sub _sshd_config {
    my ( $class, %parameters ) = @_;
    my $listen        = $parameters{listen};
    my $port          = $parameters{port};
    my $key_handle    = $parameters{key_handle};
    my $key_path      = $key_handle->filename();
    my $config_handle = $class->tmp_handle('sshd_config');
    my $config_path   = $config_handle->filename();
    print {$config_handle}
      <<"_SSHD_CONF_" or Carp::croak("Failed to write to temporary file:$EXTENDED_OS_ERROR");
HostKey $key_path
ListenAddress $listen
Port $port
_SSHD_CONF_
    seek $config_handle, 0, 0
      or Carp::croak(
        "Failed to seek to start of temporary file:$EXTENDED_OS_ERROR");
    return $config_handle;
}

sub available {
    my ( $class, %parameters ) = @_;
    my $listen        = $parameters{listen};
    my $key_size      = $parameters{key_size};
    my $port          = $class->new_port();
    my $ca            = $parameters{ca};
    my $key_handle    = $ca->new_key($key_size);
    my $config_handle = $class->_sshd_config(
        key_handle => $key_handle,
        listen     => $listen,
        port       => $port
    );
    my $config_path = $config_handle->filename();
    return $class->SUPER::available( $sshd_binary, '-e', '-t', '-f',
        $config_path );
}

sub new {
    my ( $class, %parameters ) = @_;
    my $listen        = $parameters{listen};
    my $key_size      = $parameters{key_size};
    my $ca            = $parameters{ca};
    my $port          = _DEFAULT_PORT();
    my $key_handle    = $ca->new_key($key_size);
    my $config_handle = $class->_sshd_config(
        key_handle => $key_handle,
        listen     => $listen,
        port       => $port
    );
    my $config_path = $config_handle->filename();
    my $ssh         = $class->SUPER::new(
        debug         => $parameters{debug},
        binary        => $sshd_binary,
        listen        => $listen,
        port          => $port,
        key_handle    => $key_handle,
        config_handle => $config_handle,
        arguments     => [ qw(-D -e -f), $config_path ]
    );
    return $ssh;
}

sub connect_and_exit {
    my ( $class, $host ) = @_;
    my $binary = 'ssh';
    if (
        !$class->SUPER::available(
            $binary,         '-o',  'ConnectTimeout=5', '-o',
            'BatchMode=yes', $host, 'exit 0'
        )
      )
    {
        return 0;
    }
    my $port   = $class->new_port();
    my $result = system {$binary} $binary, '-o', 'ConnectTimeout=5', '-o',
      'BatchMode=yes',
      '-o', 'StrictHostKeyChecking=accept-new', '-o',
      'ExitOnForwardFailure=yes',
      '-L', "$port:127.0.0.1:22", $host, 'exit 0';
    return $result == 0 ? return 1 : return $result;
}

package Test::Daemon::Socks;

use strict;
use warnings;
use Carp();
use English qw( -no_match_vars );

@Test::Daemon::Socks::ISA = qw(Test::Daemon Test::Binary::Available);

my $ssh_binary = __PACKAGE__->find_binary('ssh');

sub available {
    my ( $class, %parameters ) = @_;
    my $listen        = $parameters{listen};
    my $port          = $class->new_port();
    my $config_handle = $class->_sshd_config(
        listen => $listen,
        port   => $port
    );
    my $config_path = $config_handle->filename();
    return $class->SUPER::available( $ssh_binary, '-V' );
}

sub new {
    my ( $class, %parameters ) = @_;
    my $listen = $parameters{listen};
    my $port   = $class->new_port();
    my $ssh    = $class->SUPER::new(
        debug     => $parameters{debug},
        binary    => $ssh_binary,
        listen    => $listen,
        port      => $port,
        arguments => [
            qw(-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ExitOnForwardFailure=yes -ND),
            "$listen:$port",
            'localhost'
        ]
    );
    return $ssh;
}

package Test::Daemon::Botd;

use strict;
use warnings;
use Cwd();
use Carp();
use English qw( -no_match_vars );

@Test::Daemon::Botd::ISA = qw(Test::Daemon Test::Binary::Available);

my $yarn_binary =
  __PACKAGE__->find_binary('yarnpkg') || __PACKAGE__->find_binary('yarn');

sub botd_available {
    my $cwd;
    if (   ( Cwd::cwd() =~ /^(.*)$/smx )
        && ( -d File::Spec->catdir( $1, 'BotD' ) ) )
    {
        return 1;
    }
    return;
}

sub available {
    my ($class) = @_;
    return $class->SUPER::available( $yarn_binary, '--version' );
}

sub new {
    my ( $class, %parameters ) = @_;
    my $listen = $parameters{listen};
    my $port   = $class->new_port();
    my $cwd;
    if ( Cwd::cwd() =~ /^(.*)$/smx ) {
        $cwd = $1;
    }
    else {
        Carp::croak(q[Unable to untaint current working directory]);
    }
    my $git_repo_dir = File::Spec->catdir( $cwd, '.git' );
    if ( -d $git_repo_dir ) {
        system {'git'} 'git', 'submodule', 'init'
          and Carp::croak("Failed to 'git submodule init':$EXTENDED_OS_ERROR");
        system {'git'} 'git', 'submodule', 'update'
          and
          Carp::croak("Failed to 'git submodule update':$EXTENDED_OS_ERROR");
    }

    my $botd_directory = File::Spec->catdir( $cwd, 'BotD' );
    my $dev_null       = File::Spec->devnull();
    if ( my $pid = fork ) {
        waitpid $pid, 0;
    }
    elsif ( defined $pid ) {
        eval {
            local $SIG{INT}  = 'DEFAULT';
            local $SIG{TERM} = 'DEFAULT';
            chdir $botd_directory
              or
              Carp::croak("Failed to chdir $botd_directory:$EXTENDED_OS_ERROR");
            open STDOUT, q[>], $dev_null
              or Carp::croak(
                "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR");
            if ( !$parameters{debug} ) {
                open STDERR, q[>], $dev_null
                  or Carp::croak(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            open STDIN, q[<], $dev_null
              or Carp::croak(
                "Failed to redirect STDIN to $dev_null:$EXTENDED_OS_ERROR");
            exec {$yarn_binary} $yarn_binary, 'install'
              or
              Carp::croak("Failed to exec '$yarn_binary':$EXTENDED_OS_ERROR");
        } or do {
            Carp::carp($EVAL_ERROR);
        };
        exit 1;
    }
    else {
        Carp::croak("Failed to fork:$EXTENDED_OS_ERROR");
    }
    my $botd = $class->SUPER::new(
        debug     => $parameters{debug},
        binary    => $yarn_binary,
        directory => $botd_directory,
        listen    => $listen,
        resetpg   => 1,
        port      => $port,
        arguments =>
          [ q[dev:playground], q[--host], $listen, q[--port], $port ],
    );
    return $botd;
}

sub stop {
    my ($self) = @_;
    return $self->stop_process_group();
}

package Test::Daemon::FingerprintJS;

use strict;
use warnings;
use Cwd();
use Carp();
use English qw( -no_match_vars );

@Test::Daemon::FingerprintJS::ISA = qw(Test::Daemon Test::Binary::Available);

sub fingerprintjs_available {
    my $cwd;
    if (   ( Cwd::cwd() =~ /^(.*)$/smx )
        && ( -d File::Spec->catdir( $1, 'fingerprintjs' ) ) )
    {
        return 1;
    }
    return;
}

sub available {
    my ($class) = @_;
    return $class->SUPER::available( $yarn_binary, '--version' );
}

sub new {
    my ( $class, %parameters ) = @_;
    my $listen = $parameters{listen};
    my $port   = $class->new_port();
    my $cwd;
    if ( Cwd::cwd() =~ /^(.*)$/smx ) {
        $cwd = $1;
    }
    else {
        Carp::croak(q[Unable to untaint current working directory]);
    }
    my $git_repo_dir = File::Spec->catdir( $cwd, '.git' );
    if ( -d $git_repo_dir ) {
        system {'git'} 'git', 'submodule', 'init'
          and Carp::croak("Failed to 'git submodule init':$EXTENDED_OS_ERROR");
        system {'git'} 'git', 'submodule', 'update'
          and
          Carp::croak("Failed to 'git submodule update':$EXTENDED_OS_ERROR");
    }

    my $fingerprintjs_directory = File::Spec->catdir( $cwd, 'fingerprintjs' );
    my $dev_null                = File::Spec->devnull();
    if ( my $pid = fork ) {
        waitpid $pid, 0;
    }
    elsif ( defined $pid ) {
        eval {
            local $SIG{INT}  = 'DEFAULT';
            local $SIG{TERM} = 'DEFAULT';
            chdir $fingerprintjs_directory
              or Carp::croak(
                "Failed to chdir $fingerprintjs_directory:$EXTENDED_OS_ERROR");
            open STDOUT, q[>], $dev_null
              or Carp::croak(
                "Failed to redirect STDOUT to $dev_null:$EXTENDED_OS_ERROR");
            if ( !$parameters{debug} ) {
                open STDERR, q[>], $dev_null
                  or Carp::croak(
                    "Failed to redirect STDERR to $dev_null:$EXTENDED_OS_ERROR"
                  );
            }
            open STDIN, q[<], $dev_null
              or Carp::croak(
                "Failed to redirect STDIN to $dev_null:$EXTENDED_OS_ERROR");
            exec {$yarn_binary} $yarn_binary, 'install'
              or
              Carp::croak("Failed to exec '$yarn_binary':$EXTENDED_OS_ERROR");
        } or do {
            Carp::carp($EVAL_ERROR);
        };
        exit 1;
    }
    else {
        Carp::croak("Failed to fork:$EXTENDED_OS_ERROR");
    }
    my $fingerprintjs = $class->SUPER::new(
        debug     => $parameters{debug},
        binary    => $yarn_binary,
        directory => $fingerprintjs_directory,
        listen    => $listen,
        resetpg   => 1,
        port      => $port,
        arguments =>
          [ q[playground:start], q[--host], $listen, q[--port], $port ],
    );
    return $fingerprintjs;
}

sub stop {
    my ($self) = @_;
    return $self->stop_process_group();
}

1;
