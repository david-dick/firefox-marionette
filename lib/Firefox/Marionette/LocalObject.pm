package Firefox::Marionette::LocalObject;

use strict;
use warnings;
use overload q[""] => 'uuid', 'cmp' => '_cmp', q[==] => '_numeric_eq';

our $VERSION = '1.70';

sub new {
    my ( $class, $browser, %parameters ) = @_;
    my $window = bless {
        browser => $browser,
        %parameters
    }, $class;
    return $window;
}

sub TO_JSON {
    my ($self) = @_;
    my $json = {};
    if ( $self->{_old_protocols_key} ) {
        $json->{ $self->{_old_protocols_key} } = $self->uuid();
    }
    else {
        $json->{ $self->IDENTIFIER() } = $self->uuid();
    }
    return $json;
}

sub browser {
    my ($self) = @_;
    return $self->{browser};
}

sub uuid {
    my ($self) = @_;
    return $self->{ $self->IDENTIFIER() };
}

sub _cmp {
    my ( $a, $b ) = @_;
    return $a->uuid() cmp $b->uuid();
}

sub _numeric_eq {
    my ( $a, $b ) = @_;
    return $a->uuid() == $b->uuid();
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::LocalObject - Parent class that represents a Firefox local object retrieved using the Marionette protocol

=head1 VERSION

Version 1.70

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Cwd();

    my $path = File::Spec->catfile(Cwd::cwd(), qw(t data elements.html));
    my $firefox = Firefox::Marionette->new()->go("file://$path");
    # getting a reference to a browser object in perl
    my $span = $firefox->has_tag('span');
    # working on that referenced object back in the browser
    my $child = $firefox->script('return arguments[0].children[0]', args => [ $span ]);

=head1 DESCRIPTION

This module handles the implementation of a Firefox L<local object|https://www.w3.org/TR/webdriver/#dfn-local-ends> using the Marionette protocol.  It is here to provide a single place for common methods for this type of object and should not be instantiated directly.

=head1 SUBROUTINES/METHODS

=head2 browser

returns the L<browser|Firefox::Marionette> connected with this object.

=head2 new

returns a new object.

=head2 TO_JSON

required to allow L<JSON serialisation|https://metacpan.org/pod/JSON#OBJECT-SERIALISATION> to work correctly.  This method should not need to be called directly.

=head2 uuid

returns the browser generated id connected with this object.  The id is usually a UUID, but may not be, especially for older versions of Firefox

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::LocalObject requires no configuration files or environment variables.

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
