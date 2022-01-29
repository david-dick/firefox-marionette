package Firefox::Marionette::Buttons;

use strict;
use warnings;
use Exporter();
*import = \&Exporter::import;
our @EXPORT_OK = qw(
  LEFT_BUTTON
  MIDDLE_BUTTON
  RIGHT_BUTTON
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK, );

our $VERSION = '1.22';

sub LEFT_BUTTON   { return 0 }
sub MIDDLE_BUTTON { return 1 }
sub RIGHT_BUTTON  { return 2 }

1;    # Magic true value required at end of module
__END__
=head1 NAME

Firefox::Marionette::Buttons - Human readable mouse buttons for the Marionette protocol

=head1 VERSION

Version 1.22

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Firefox::Marionette::Buttons qw(:all);
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org');

    my $help_button = $firefox->find_class('btn search-btn help-btn');
    $firefox->perform(
			$firefox->mouse_move($help_button),
			$firefox->mouse_down(RIGHT_BUTTON()),
			$firefox->mouse_up(RIGHT_BUTTON()),
		);

=head1 DESCRIPTION

This module handles the implementation of the Firefox Marionette human readable mouse buttons

=head1 SUBROUTINES/METHODS

=head2 LEFT_BUTTON

returns the left mouse button code, which is 0.

=head2 MIDDLE_BUTTON

returns the middle mouse button code, which is 1.

=head2 RIGHT_BUTTON

returns the right mouse button code, which is 2.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Buttons requires no configuration files or environment variables.

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
