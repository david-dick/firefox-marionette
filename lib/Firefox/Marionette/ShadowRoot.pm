package Firefox::Marionette::ShadowRoot;

use strict;
use warnings;
use parent qw(Firefox::Marionette::LocalObject);

our $VERSION = '1.50';

sub IDENTIFIER { return 'shadow-6066-11e4-a52e-4f735466cecf' }

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::ShadowRoot - Represents a Firefox shadow root retrieved using the Marionette protocol

=head1 VERSION

Version 1.50

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new()->go('file://' . Cwd::cwd() . '/t/data/elements.html');
    $firefox->find_class('add')->click();
    my $shadow_root = $firefox->find_tag('custom-square')->shadow_root();

    foreach my $element (@{$firefox->script('return arguments[0].children', args => [ $shadow_root ])}) {
        warn $element->tag_name();
    }

=head1 DESCRIPTION

This module handles the implementation of a Firefox Shadow Root using the Marionette protocol

=head1 CONSTANTS

=head2 IDENTIFIER

returns the L<shadow root identifier|https://www.w3.org/TR/webdriver/#shadow-root>

=head1 SUBROUTINES/METHODS

=head2 new

returns a new L<shadow root|Firefox::Marionette::ShadowRoot>.

=head2 uuid

returns the browser generated UUID connected with this L<shadow root|Firefox::Marionette::ShadowRoot>.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::ShadowRoot requires no configuration files or environment variables.

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
