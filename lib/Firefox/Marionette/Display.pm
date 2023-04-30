package Firefox::Marionette::Display;

use strict;
use warnings;

our $VERSION = '1.37';

sub new {
    my ( $class, %parameters ) = @_;
    my $self = bless {%parameters}, $class;
    return $self;
}

sub designation {
    my ($self) = @_;
    return $self->{designation};
}

sub usage {
    my ($self) = @_;
    return $self->{usage};
}

sub width {
    my ($self) = @_;
    return $self->{width};
}

sub height {
    my ($self) = @_;
    return $self->{height};
}

sub sar {
    my ($self) = @_;
    return $self->{sar};
}

sub dar {
    my ($self) = @_;
    return $self->{dar};
}

sub par {
    my ($self) = @_;
    return $self->{par};
}

sub total {
    my ($self) = @_;
    return $self->{width} * $self->{height};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Display - Represents a display from the displays method

=head1 VERSION

Version 1.37

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    my $element = $firefox->find_id('metacpan_search-input');
    foreach my $display ($firefox->displays()) {
        say 'Can Firefox resize for "' . Encode::encode('UTF-8', $display->usage(), 1) . '"?';
        if ($firefox->resize($display->width(), $display->height())) {
            say 'Now displaying with a Pixel aspect ratio of ' . $display->par();
            say 'Now displaying with a Storage aspect ratio of ' . $display->sar();
            say 'Now displaying with a Display aspect ratio of ' . $display->dar();
	} else {
            say 'Apparently NOT!';
        }
    }

=head1 DESCRIPTION

This module handles the implementation of a L<display|https://en.wikipedia.org/wiki/List_of_common_resolutions>.

=head1 SUBROUTINES/METHODS

=head2 dar

returns the L<Display aspect ratio|https://en.wikipedia.org/wiki/Display_aspect_ratio> for the display.

=head2 designation

returns the L<designation|https://en.wikipedia.org/wiki/List_of_common_resolutions> value, such as "VGA" or "16K".

=head2 height

returns the resolution height

=head2 new

accepts a hash for the display with the following allowed keys;

=over 4

=item * designation - See the L<designation|https://en.wikipedia.org/wiki/List_of_common_resolutions> column.

=item * usage - See the L<usage|https://en.wikipedia.org/wiki/List_of_common_resolutions> column.

=item * width - The width of the entire firefox window.

=item * height - The height of the entire firefox window.

=item * sar - The L<Storage aspect ratio|https://en.wikipedia.org/wiki/Aspect_ratio_(image)#storage_aspect_ratio>, which is related to the below ratios with the equation SAR = PAR/DAR.

=item * dar - The L<Display aspect ratio|https://en.wikipedia.org/wiki/Display_aspect_ratio>.

=item * par - The L<Pixel aspect ratio|https://en.wikipedia.org/wiki/Pixel_aspect_ratio>.

=back

=head2 par

returns the L<Pixel aspect ratio|https://en.wikipedia.org/wiki/Pixel_aspect_ratio> for the display.

=head2 sar

returns the L<Storage aspect ratio|https://en.wikipedia.org/wiki/Aspect_ratio_(image)#storage_aspect_ratio>, which is related to the below ratios with the equation SAR = PAR/DAR.

=head2 total

returns the product of L<height|Firefox::Marionette::Display#height> and L<width|Firefox::Marionette::Display#width>.

=head2 usage

returns the L<usage|https://en.wikipedia.org/wiki/List_of_common_resolutions> value such as "Apple PowerBook G4".

=head2 width

returns the resolution width

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Display requires no configuration files or environment variables.

=head1 DEPENDENCIES

Firefox::Marionette::Display does not requires any non-core Perl modules
 
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
