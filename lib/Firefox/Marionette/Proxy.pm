package Firefox::Marionette::Proxy;

use strict;
use warnings;

our $VERSION = '1.43';

sub new {
    my ( $class, %parameters ) = @_;
    if ( $parameters{pac} ) {
        $parameters{pac} = "$parameters{pac}";
    }
    elsif ( $parameters{host} ) {
        $parameters{type} = 'manual';
        my $host = "$parameters{host}";
        if ( $host !~ /:\d+$/smx ) {
            $host .= q[:80];
        }
        $parameters{http}  = $host;
        $parameters{https} = $host;
    }
    elsif ( $parameters{tls} ) {
        $parameters{pac} =
qq[data:text/plain,function FindProxyForURL(){return "HTTPS $parameters{tls}"}];
    }
    my $element = bless {%parameters}, $class;
    return $element;
}

sub type {
    my ($self) = @_;
    return $self->{type};
}

sub pac {
    my ($self) = @_;
    return URI->new( $self->{pac} );
}

sub ftp {
    my ($self) = @_;
    return $self->{ftp};
}

sub http {
    my ($self) = @_;
    return $self->{http};
}

sub none {
    my ($self) = @_;
    if ( defined $self->{none} ) {
        if ( ref $self->{none} ) {
            return @{ $self->{none} };
        }
        else {
            return ( $self->{none} );
        }
    }
    else {
        return ();
    }
}

sub https {
    my ($self) = @_;
    return $self->{https};
}

sub socks {
    my ($self) = @_;
    return $self->{socks};
}

sub socks_version {
    my ($self) = @_;
    return $self->{socks_version};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Proxy - Represents a Proxy used by Firefox Capabilities using the Marionette protocol

=head1 VERSION

Version 1.43

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $proxy = Firefox::Marionette::Proxy->new( pac => 'http://gateway.example.com/' );
    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( proxy => $proxy ) );
    foreach my $address ($firefox->capabilities->proxy()->none()) {
        say "Browser will ignore the proxy for $address";
    }

    # OR 

    my $proxy = Firefox::Marionette::Proxy->new( host => 'squid.example.com:3128' );
    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( proxy => $proxy ) );

    # OR

    my $proxy = Firefox::Marionette::Proxy->new( tls => "squid.example.org:443" );
    my $firefox = Firefox::Marionette->new(capabilities => Firefox::Marionette::Capabilities->new(proxy => $proxy));

=head1 DESCRIPTION

This module handles the implementation of a Proxy in Firefox Capabilities using the Marionette protocol

=head1 SUBROUTINES/METHODS

=head2 new
 
accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * type - indicates the type of proxy configuration.  Must be one of 'pac', 'direct', 'autodetect', 'system', or 'manual'.

=item * pac - defines the L<URI|URI> for a proxy auto-config file if the L<type|Firefox::Marionette::Proxy#type> is equal to 'pac'.

=item * host - defines the host for FTP, HTTP, and HTTPS traffic and sets the L<type|Firefox::Marionette::Proxy#type> to 'manual'.

=item * http - defines the proxy host for HTTP traffic when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=item * https - defines the proxy host for encrypted TLS traffic when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=item * none - lists the addresses for which the proxy should be bypassed when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.  This may be a list of domains, IPv4 addresses, or IPv6 addresses.

=item * socks - defines the proxy host for a SOCKS proxy traffic when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=item * socks_version - defines the SOCKS proxy version when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.  It must be any integer between 0 and 255 inclusive, but it defaults to '5'.

=item * tls - defines a L<pac|Firefox::Marionette::Proxy#type> function pointing to a TLS secured proxy for FTP, HTTP, and HTTPS traffic.  This was derived from L<bug 378637|https://bugzilla.mozilla.org/show_bug.cgi?id=378637>

=back

This method returns a new L<proxy|Firefox::Marionette::Proxy> object.
 
=head2 type

returns the type of proxy configuration.  Must be one of 'pac', 'direct', 'autodetect', 'system', or 'manual'.

=head2 pac

returns the L<URI|URI> for a proxy auto-config file if the L<type|Firefox::Marionette::Proxy#type> is equal to 'pac'.

=head2 http

returns the proxy host for HTTP traffic when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=head2 https

returns the proxy host for encrypted TLS traffic when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=head2 none

returns a list of the addresses for which the proxy should be bypassed when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.  This may be a list of domains, IPv4 addresses, or IPv6 addresses.

=head2 socks

returns the proxy host for a SOCKS proxy traffic when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=head2 socks_version

returns the SOCKS proxy version when the L<type|Firefox::Marionette::Proxy#type> is 'manual'.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Proxy requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

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
