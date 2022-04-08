package Firefox::Marionette::Exception::Response;

use strict;
use warnings;
use base qw(Firefox::Marionette::Exception);

our $VERSION = '1.24';

sub throw {
    my ( $class, $response ) = @_;
    my $self = bless {
        string => $response->error()->{error} . q[: ]
          . $response->error()->{message},
        response => $response
    }, $class;
    return $self->SUPER::_throw();
}

sub status {
    my ($self) = @_;
    return $self->{response}->error()->{status};
}

sub message {
    my ($self) = @_;
    return $self->{response}->error()->{message};
}

sub error {
    my ($self) = @_;
    return $self->{response}->error()->{error};
}

sub trace {
    my ($self) = @_;
    return $self->{response}->error()->{stacktrace};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Exception::Response - Represents an exception thrown by Firefox

=head1 VERSION

Version 1.24

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

=head1 DESCRIPTION

This module handles the implementation of an error in a Marionette protocol response.  

=head1 SUBROUTINES/METHODS

=head2 error

returns the firefox error message.  Only available in recent firefox versions

=head2 message

returns a text description of the error.  This is the most reliable method to give the user some indication of what is happening across all firefox versions.

=head2 status

returns the firefox status, a numeric identifier in older versions of firefox (such as 38.8)

=head2 throw
 
accepts a Marionette L<response|Firefox::Marionette::Response> as it's only parameter and calls Carp::croak.

=head2 trace

returns the firefox trace.  Only available in recent firefox versions.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Exception::Response requires no configuration files or environment variables.

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
