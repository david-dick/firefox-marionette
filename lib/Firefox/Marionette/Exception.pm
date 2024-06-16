package Firefox::Marionette::Exception;

use strict;
use warnings;
use Carp();
use overload '""' => 'string';

our $VERSION = '1.58';

sub throw {
    my ( $class, $string ) = @_;
    my $self = bless { string => $string }, $class;
    return $self->_throw();
}

sub _throw {
    my ($self) = @_;
    my $index = 0;
    my ( $package, $file, $line ) = caller $index++;
    while ( $package =~ /^Firefox::Marionette/smx ) {
        ( $package, $file, $line ) = caller $index++;
    }
    $self->{origin} = $package eq 'main' ? $file : $package;
    $self->{line}   = $line;
    Carp::croak($self);
}

sub string {
    my ($self) = @_;
    return
        $self->{string} . q[ at ]
      . $self->{origin}
      . q[ line ]
      . $self->{line} . qq[\n];
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Exception - Represents an base exception class for exceptions for Firefox::Marionette

=head1 VERSION

Version 1.58

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

=head1 DESCRIPTION

This module handles the implementation of an exception in Firefox::Marionette.

=head1 SUBROUTINES/METHODS

=head2 throw
 
accepts a string as it's only parameter and calls Carp::croak.

=head2 string

returns a stringified version of the exception.

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

Copyright (c) 2024, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

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
