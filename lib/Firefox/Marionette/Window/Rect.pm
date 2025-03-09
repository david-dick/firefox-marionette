package Firefox::Marionette::Window::Rect;

use strict;
use warnings;

our $VERSION = '1.63';

sub new {
    my ( $class, %parameters ) = @_;
    my $window = bless {%parameters}, $class;
    return $window;
}

sub pos_x {
    my ($self) = @_;
    return $self->{pos_x};
}

sub pos_y {
    my ($self) = @_;
    return $self->{pos_y};
}

sub width {
    my ($self) = @_;
    return $self->{width};
}

sub height {
    my ($self) = @_;
    return $self->{height};
}

sub wstate {
    my ($self) = @_;
    return $self->{wstate};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Window::Rect - Represents the browser window's shape and size

=head1 VERSION

Version 1.63

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $rect = $firefox->rect();
    say "Current height of the window " . $window->height();

=head1 DESCRIPTION

This module handles the representation of the browser window

=head1 SUBROUTINES/METHODS

=head2 new
 
accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * pos_x - the X position of the window.  This function will return undef for older Firefoxen.

=item * pos_y - the Y position of the window.  This function will return undef for older Firefoxen.

=item * height - the height of the window

=item * width - the width of the window

=item * wstate - the state of the window as a scalar string.  This function will return undef for Firefox versions less than 57

=back

This method returns a new L<rect|Firefox::Marionette::Window::Rect> object.
 
=head2 pos_x

returns the X position of the window

=head2 pos_y

returns the Y position of the window

=head2 height

returns the height of the window

=head2 width

returns the width of the window

=head2 wstate

returns a scalar representing the state of the window. For example 'maximized'.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Window::Rect requires no configuration files or environment variables.

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
