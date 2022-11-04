package Waterfox::Marionette;

use warnings;
use strict;
use English qw( -no_match_vars );
use Waterfox::Marionette::Profile();
use base qw(Firefox::Marionette);
Firefox::Marionette->import(qw(:all));

our @EXPORT_OK =
  qw(BY_XPATH BY_ID BY_NAME BY_TAG BY_CLASS BY_SELECTOR BY_LINK BY_PARTIAL);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

our $VERSION = '1.28';

sub default_binary_name {
    return 'waterfox';
}

sub macos_binary_paths {
    my ($self) = @_;
    return (
        '/Applications/Waterfox Current.app/Contents/MacOS/waterfox',
        '/Applications/Waterfox Classic.app/Contents/MacOS/waterfox',
    );
}

my %_known_win32_organisations = (
    'Waterfox'         => 'WaterfoxLimited',
    'Waterfox Current' => 'Waterfox',
    'Waterfox Classic' => 'Waterfox',
);

sub win32_organisation {
    my ( $self, $name ) = @_;
    return $_known_win32_organisations{$name};
}

sub win32_product_names {
    my ($self) = @_;
    my %known_win32_preferred_names = (
        'Waterfox'         => 1,
        'Waterfox Current' => 2,
        'Waterfox Classic' => 3,
    );
    return %known_win32_preferred_names;
}

1;    # Magic true value required at end of module
__END__
=head1 NAME

Waterfox::Marionette - Automate the Waterfox browser with the Marionette protocol

=head1 VERSION

Version 1.28

=head1 SYNOPSIS

    use Waterfox::Marionette();
    use v5.10;

    my $waterfox = Waterfox::Marionette->new()->go('https://metacpan.org/');

    say $waterfox->find_tag('title')->property('innerHTML'); # same as $waterfox->title();

    say $waterfox->html();

    $waterfox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    say "Height of page-content div is " . $waterfox->find_class('page-content')->css('height');

    my $file_handle = $waterfox->selfie();

    $waterfox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $waterfox->find_partial('Download')->click();


=head1 DESCRIPTION

This is a client module to automate the Waterfox browser via the L<Marionette protocol|https://developer.mozilla.org/en-US/docs/Mozilla/QA/Marionette/Protocol>.

It inherits most of it's methods from L<Firefox::Marionette|Firefox::Marionette>.

=head1 SUBROUTINES/METHODS

For a full list of methods available, see L<Firefox::Marionette|Firefox::Marionette#SUBROUTINES/METHODS>

=head2 default_binary_name

just returns the string 'waterfox'.  See L<Firefox::Marionette|Firefox::Marionette#default_binary_name>.

=head2 macos_binary_paths

returns a list of filesystem paths that this module will check for binaries that it can automate when running on L<MacOS|https://en.wikipedia.org/wiki/MacOS>.  See L<Firefox::Marionette|Firefox::Marionette#macos_binary_paths>.

=head2 win32_organisation

accepts a parameter of a Win32 product name and returns the matching organisation.  See L<Firefox::Marionette|Firefox::Marionette#win32_organisation>.

=head2 win32_product_names

returns a hash of known Windows product names (such as 'Waterfox') with priority orders.  See L<Firefox::Marionette|Firefox::Marionette#win32_product_names>.

=head1 DIAGNOSTICS

For diagnostics, see L<Firefox::Marionette|Firefox::Marionette#DIAGNOSTICS>

=head1 CONFIGURATION AND ENVIRONMENT

For configuration, see L<Firefox::Marionette|Firefox::Marionette#CONFIGURATION AND ENVIRONMENT>

=head1 DEPENDENCIES

For dependencies, see L<Firefox::Marionette|Firefox::Marionette#DEPENDENCIES>
 
=head1 INCOMPATIBILITIES

None reported.  Always interested in any products with marionette support that this module could be patched to work with.

=head1 BUGS AND LIMITATIONS

See L<Firefox::Marionette|Firefox::Marionette#BUGS AND LIMITATIONS>

=head1 AUTHOR

David Dick  C<< <ddick@cpan.org> >>

=head1 ACKNOWLEDGEMENTS
 
Thanks for the L<Waterfox browser|https://www.waterfox.net/>
 
=head1 LICENSE AND COPYRIGHT

Copyright (c) 2021, David Dick C<< <ddick@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic/perlartistic>.

The L<Firefox::Marionette::Extension::HarExportTrigger|Firefox::Marionette::Extension::HarExportTrigger> module includes the L<HAR Export Trigger|https://github.com/firefox-devtools/har-export-trigger>
extension which is licensed under the L<Mozilla Public License 2.0|https://www.mozilla.org/en-US/MPL/2.0/>.

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
