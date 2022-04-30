package Firefox::Marionette::Link;

use strict;
use warnings;
use URI::URL();

use base qw(Firefox::Marionette::Element);

our $VERSION = '1.26';

sub new {
    my ( $class, $element ) = @_;
    my $self = $element;
    bless $self, $class;
    return $self;
}

sub url {
    my ($self) = @_;
    my %attributes = $self->attrs();
    return $attributes{href};
}

sub text {
    my ($self) = @_;
    my $text = $self->browser()
      ->script( 'return arguments[0].innerText;', args => [$self] );
    if ( defined $text ) {
        $text =~ s/^\s*//smx;
        $text =~ s/\s*$//smx;
    }
    return $text;
}

sub name {
    my ($self) = @_;
    my %attributes = $self->attrs();
    return $attributes{name};
}

sub tag {
    my ($self) = @_;
    return $self->tag_name();
}

sub base {
    my ($self) = @_;
    return $self->browser()->uri();
}

sub attrs {
    my ($self) = @_;
    return %{
        $self->browser()->script(
'let namedNodeMap = arguments[0].attributes; let attributes = {}; for(let i = 0; i < namedNodeMap.length; i++) { var attr = namedNodeMap.item(i); if (attr.specified) { attributes[attr.name] = attr.value } }; return attributes;',
            args => [$self]
        )
    };
}

sub URI {
    my ($self) = @_;
    my %attributes = $self->attrs();
    return URI::URL->new_abs( $attributes{href}, $self->base() );
}

sub url_abs {
    my ($self) = @_;
    return $self->URI()->abs();
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Link - Represents a link from the links method

=head1 VERSION

Version 1.26

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('http://metacpan.org');;
    foreach my $link ($firefox->links()) {
        if ($link->type() eq 'a') {
            say "Link to " . $link->URI();
        } elsif ($line->type() eq 'meta') {
            say "Meta name is " . $link->name();
        }
    }

=head1 DESCRIPTION

This module is a super class of L<Firefox::Marionette::Element|Firefox::Marionette::Element> designed to be compatible with L<WWW::Mechanize::Link|WWW::Mechanize::Link>.

=head1 SUBROUTINES/METHODS

=head2 attrs

returns the attributes for the link as a hash.

=head2 base

returns the base url to which all links are relative.

=head2 name

returns the name attribute, if any.

=head2 new

accepts an L<element|Firefox::Marionette::Element> as a parameter and returns a L<link|Firefox::Marionette::Link> object

=head2 tag

returns the tag (one of: "a", "area", "frame", "iframe" or "meta").

=head2 text

returns the text of the link, specifically the L<innerText|https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/innerText>.

=head2 url

returns the URL of the link.

=head2 URI

returns the URL as a URI::URL object.

=head2 url_abs

returns the URL as an absolute URL string.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Link requires no configuration files or environment variables.

=head1 DEPENDENCIES

Firefox::Marionette::Link requires the following non-core Perl modules
 
=over
 
=item *
L<URI::URL|URI::URL>

=back

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
