package Firefox::Marionette::WebWindow;

use strict;
use warnings;
use parent qw(Firefox::Marionette::LocalObject);

our $VERSION = '1.61';

sub IDENTIFIER { return 'window-fcc6-11e5-b4f8-330a88ab9d7f' }

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::WebWindow - Represents a Firefox window retrieved using the Marionette protocol

=head1 VERSION

Version 1.61

=head1 SYNOPSIS

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    my $original_window = $firefox->window_handle();
    my $javascript_window = $firefox->script('return window'); # only works for Firefox 121 and later
    if ($javascript_window ne $original_window) {
        die "That was unexpected!!! What happened?";
    }

=head1 DESCRIPTION

This module handles the implementation of a Firefox Window using the Marionette protocol

=head1 CONSTANTS

=head2 IDENTIFIER

returns the L<window identifier|https://www.w3.org/TR/webdriver/#dfn-window-handles>

=head1 SUBROUTINES/METHODS

=head2 new

returns a new L<window|Firefox::Marionette::WebWindow>.

=head2 uuid

returns the browser generated UUID connected with this L<window|Firefox::Marionette::WebWindow>.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::WebWindow requires no configuration files or environment variables.

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
