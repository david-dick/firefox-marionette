package Firefox::Marionette::Cookie;

use strict;
use warnings;

our $VERSION = '1.24';

sub new {
    my ( $class, %parameters ) = @_;
    my $cookie = bless {
        http_only => $parameters{http_only} ? 1 : 0,
        secure    => $parameters{secure}    ? 1 : 0,
        domain    => $parameters{domain},
        path      => defined $parameters{path} ? $parameters{path} : q[/],
        value     => $parameters{value},
        name      => $parameters{name},
    }, $class;
    if ( defined $parameters{expiry} ) {
        $cookie->{expiry} = $parameters{expiry};
    }
    if ( defined $parameters{same_site} ) {
        $cookie->{same_site} = $parameters{same_site};
    }
    return $cookie;
}

sub http_only {
    my ($self) = @_;
    return $self->{http_only};
}

sub secure {
    my ($self) = @_;
    return $self->{secure};
}

sub domain {
    my ($self) = @_;
    return $self->{domain};
}

sub path {
    my ($self) = @_;
    return $self->{path};
}

sub value {
    my ($self) = @_;
    return $self->{value};
}

sub expiry {
    my ($self) = @_;
    return $self->{expiry};
}

sub same_site {
    my ($self) = @_;
    return $self->{same_site};
}

sub name {
    my ($self) = @_;
    return $self->{name};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Cookie - Represents a Firefox cookie retrieved using the Marionette protocol

=head1 VERSION

Version 1.24

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    foreach my $cookie ($firefox->cookies()) {
        say "Cookie name is " . $cookie->name();
    }

=head1 DESCRIPTION

This module handles the implementation of a single Firefox cookie using the Marionette protocol

=head1 SUBROUTINES/METHODS

=head2 new
 
accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * http_only - the httpOnly flag on the cookie.  Allowed values are 1 or 0.  Default is 0.

=item * secure - the secure flag on the cookie.  Allowed values are 1 or 0.  Default is 0.

=item * domain - the domain name belonging to the cookie.

=item * path - the path belonging to the cookie. 

=item * expiry - the expiry time of the cookie in seconds since the UNIX epoch.  expiry will return undef for Firefox versions less than 56

=item * value - the value of the cookie. 

=item * same_site - should the cookie be restricted to a first party or same-site context.  See L<MSDN|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite>.

=item * name - the name of the cookie. 

=back

This method returns a new L<cookie|Firefox::Marionette::Cookie> object.
 
=head2 http_only

returns the value of the httpOnly flag.

=head2 secure

returns the value of the secure flag.

=head2 domain

returns the value of cookies domain. For example '.metacpan.org'

=head2 path

returns the value of cookies path. For example '/search'.

=head2 expiry

returns the integer value of the cookies expiry time in seconds since the UNIX epoch.

=head2 value

returns the value of the cookie.

=head2 same_site

returns the L<Same Site|https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite> value for the cookie (if any).

=head2 name

returns the name of the cookie.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Cookie requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

To report a bug, or view the current list of bugs, please visit L<https://github.com/david-dick/firefox-marionette/issues>

=head1 AUTHOR

David Dick  C<< <ddick@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2021, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

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
