package Firefox::Marionette::Bookmark;

use strict;
use warnings;
use URI::URL();
use URI::data();
use Exporter();
*import = \&Exporter::import;
our @EXPORT_OK = qw(
  BOOKMARK
  FOLDER
  MENU
  MOBILE
  ROOT
  SEPARATOR
  TAGS
  TOOLBAR
  UNFILED
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK, );

our $VERSION = '1.55';

# guids from toolkit/components/places/Bookmarks.sys.mjs

sub MENU   { return 'menu________' }
sub MOBILE { return 'mobile______' }
sub ROOT   { return 'root________' }

sub TAGS {
    return 'tags________';
}    # With bug 424160, tags will stop being bookmarks
sub TOOLBAR { return 'toolbar_____' }
sub UNFILED { return 'unfiled_____' }

# types from toolkit/components/places/nsINavBookmarksService.idl

sub BOOKMARK  { return 1 }
sub FOLDER    { return 2 }
sub SEPARATOR { return 3 }

my %mapping = (
    guid          => 'guid',
    keyword       => 'keyword',
    url           => 'url',
    title         => 'title',
    type          => 'type',
    tags          => 'tags',
    index         => 'index',
    parent_guid   => 'parentGuid',
    date_added    => 'dateAdded',
    last_modified => 'lastModified',
    icon_url      => 'iconUrl',
    icon          => 'icon',
);

sub new {
    my ( $class, %parameters ) = @_;
    my $bookmark = bless {}, $class;
    foreach my $name (
        qw(parent_guid guid url title date_added last_modified type icon icon_url index tags keyword)
      )
    {
        if ( defined $parameters{$name} ) {
            $bookmark->{$name} = $parameters{$name};
        }
        if ( defined $parameters{ $mapping{$name} } ) {
            $bookmark->{$name} = $parameters{ $mapping{$name} };
        }
    }
    foreach my $name (qw(url icon_url)) {
        if ( defined $bookmark->{$name} ) {
            $bookmark->{$name} = URI::URL->new( $bookmark->{$name} );
        }
    }
    foreach my $name (qw(icon)) {
        if ( defined $bookmark->{$name} ) {
            $bookmark->{$name} = URI::data->new( $bookmark->{$name} );
        }
    }
    if ( !defined $bookmark->{type} ) {
        if ( defined $bookmark->{url} ) {
            $bookmark->{type} = BOOKMARK();
        }
        elsif ( defined $bookmark->{title} ) {
            $bookmark->{type} = FOLDER();
        }
    }
    if ( ( defined $bookmark->{guid} ) && ( $bookmark->{guid} eq ROOT() ) ) {
    }
    else {
        $bookmark->{parent_guid} =
          $bookmark->{parent_guid} ? $bookmark->{parent_guid} : MENU();
    }
    return $bookmark;
}

sub TO_JSON {
    my ($self) = @_;
    my $json = {};
    foreach my $key ( sort { $a cmp $b } keys %{$self} ) {
        if ( ( $key eq 'url' ) || ( $key eq 'icon_url' ) || ( $key eq 'icon' ) )
        {
            $json->{ $mapping{$key} } = $self->{$key}->as_string();
        }
        else {
            $json->{ $mapping{$key} } = $self->{$key};
        }
        if ( ( $key eq 'date_added' ) || ( $key eq 'last_modified' ) ) {
            $json->{ $mapping{$key} } =~ s/000$//smx;
        }
    }
    return $json;
}

sub url {
    my ($self) = @_;
    return $self->{url};
}

sub title {
    my ($self) = @_;
    return $self->{title};
}

sub guid {
    my ($self) = @_;
    return $self->{guid};
}

sub type {
    my ($self) = @_;
    return $self->{type};
}

sub content_type {
    my ($self) = @_;
    if ( my $type = $self->type() ) {
        if ( $type == BOOKMARK() ) {
            return 'text/x-moz-place';
        }
        elsif ( $type == FOLDER() ) {
            return 'text/x-moz-place-container';
        }
        elsif ( $type == SEPARATOR() ) {
            return 'text/x-moz-place-separator';
        }
    }
    return;
}

sub parent_guid {
    my ($self) = @_;
    return $self->{parent_guid};
}

sub date_added {
    my ($self) = @_;
    return $self->{date_added};
}

sub last_modified {
    my ($self) = @_;
    return $self->{last_modified};
}

sub idx {
    my ($self) = @_;
    return $self->{index};
}

sub icon {
    my ($self) = @_;
    return $self->{icon};
}

sub icon_url {
    my ($self) = @_;
    return $self->{icon_url};
}

sub tags {
    my ($self) = @_;
    if ( defined $self->{tags} ) {
        return @{ $self->{tags} };
    }
    else {
        return ();
    }
}

sub keyword {
    my ($self) = @_;
    return $self->{keyword};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Bookmark - Represents a Firefox bookmark retrieved using the Marionette protocol

=head1 VERSION

Version 1.55

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Firefox::Marionette::Bookmark qw(:all);
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    $firefox->import_bookmarks("/path/to/bookmarks.html");

    foreach my $bookmark (reverse $firefox->bookmarks()) {
        say "Bookmark guid is          :" . $bookmark->guid();
        say "Bookmark parent guid is   :" . $bookmark->parent_guid();
        say "Bookmark date added is    :" . localtime($bookmark->date_added());
        say "Bookmark last modified is :" . localtime($bookmark->last_modified());
        say "Bookmark index is         :" . $bookmark->idx();
        if ($bookmark->type() == BOOKMARK()) {
            say "Bookmark url              :" . $bookmark->url();
            say "Bookmark title is         :" . Encode::encode('UTF-8', $bookmark->title(), 1) if ($bookmark->title());
            say "Bookmark icon is          :" . $bookmark->icon() if ($bookmark->icon());
            say "Bookmark icon url is      :" . $bookmark->icon_url() if ($bookmark->icon_url());
            say "Bookmark keyword is       :" . Encode::encode('UTF-8', $bookmark->keyword(), 1) if ($bookmark->keyword());
            say "Bookmark tags are         :" . Encode::encode('UTF-8', (join q[, ], $bookmark->tags())) if ($bookmark->tags());
        } elsif ($bookmark->type() == FOLDER()) {
            given ($bookmark->guid()) {
                when (MENU() . q[])    { say "This is the menu folder" }
                when (ROOT() . q[])    { say "This is the root folder" }
                when (TAGS() . q[])    { say "This is the tags folder" }
                when (TOOLBAR() . q[]) { say "This is the toolbar folder" }
                when (UNFILED() . q[]) { say "This is the unfiled folder" }
                when (MOBILE() . q[])  { say "This is the mobile folder" }
                default                { say "Folder title is           :" . $bookmark->title() }
            }
        } else {
            say "-" x 50;
        }
    }


=head1 DESCRIPTION

This module handles the implementation of a single Firefox bookmark using the Marionette protocol.

=head1 CONSTANTS

Constants are sourced from L<toolkit/components/places/Bookmarks.sys.mjs|https://hg.mozilla.org/mozilla-central/file/tip/toolkit/components/places/Bookmarks.sys.mjs>.

=head2 ROOT

returns the guid of the root of the bookmark hierarchy.  This is equal to the string 'root________'.

=head2 MENU 

return the guid for the menu folder.  This is equal to the string 'menu________'.

=head2 TAGS

return the guid for the tags folder.  This is equal to the string 'tags________'. With L<bug 424160|https://bugzilla.mozilla.org/show_bug.cgi?id=424160>, tags will stop being bookmarks.

=head2 TOOLBAR

return the guid for the toolbar folder.  This is equal to the string 'toolbar_____'.

=head2 UNFILED

return the guid for the unfiled folder.  This is equal to the string 'unfiled_____'.

=head2 MOBILE

return the guid for the mobile folder.  This is equal to the string 'mobile______'.

=head2 BOOKMARK

returns the integer 1.

=head2 FOLDER

returns the integer 2.

=head2 SEPARATOR

returns the integer 3.

=head1 SUBROUTINES/METHODS

=head2 new
 
accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * date_added.  the time the bookmark was added in seconds since the UNIX epoch.

=item * icon - the favicon for the bookmark.  It should be encoded as a L<data URI|URI::data>.

=item * icon_url - the url for the bookmark favicon.  It should be encoded as a L<URL|URI::URL>.

=item * index - the index of the bookmark.  This describes the bookmark's position in the hierarchy.

=item * guid - the unique identifier for the bookmark in Firefox.  This key is optional.  If the a bookmark is saved without a guid, firefox will generate a guid automatically.

=item * last_modified - the time the bookmark was last modified in seconds since the UNIX epoch.

=item * parent_guid - the guid of the parent folder in the bookmark hierarchy.  The default parent guid will be the L<MENU|/MENU>.

=item * title - the title of the bookmark.  This can be a L<folder name|/FOLDER> name or a L<bookmark|/BOOKMARK> title.

=item * type - an integer describing the type of this object.  It can be a L<bookmark|/BOOKMARK>, a L<folder|/FOLDER> or a L<separator|/SEPARATOR>.

=item * url - the L<url|/url> of the bookmark.  Only bookmarks with a type of L<BOOKMARK|/BOOKMARK> will have a L<url|/url> set.

=back

This method returns a new L<bookmark|Firefox::Marionette::Bookmark> object.
 
=head2 content_type

returns the content type of the bookmark (for example 'text/x-moz-place-container' for a folder).

=head2 date_added

returns the time the bookmark was added in seconds since the UNIX epoch.

=head2 icon

returns the favicon of the bookmark if known.  It will be returned as a L<data URI|URI::data> object.

=head2 icon_url

returns the URL of the favicon of the bookmark if known.  It will be returned as a L<URL|URI::URL> object.

=head2 idx

returns the index of the bookmark.  This will be an integer.

=head2 guid

returns the guid of the bookmark.  This will be a unique value for the hierarchy and 12 characters in length.  There are special guids, which are the L<ROOT|/ROOT>, L<MENU|/MENU>, L<TOOLBAR|/TOOLBAR>, L<UNFILED|/UNFILED> and L<MOBILE|/MOBILE> guids.

=head2 keyword

returns the L<keyword|https://support.mozilla.org/en-US/kb/bookmarks-firefox#w_how-to-use-keywords-with-bookmarks> (if any) associated with the bookmark.

=head2 last_modified

returns the time the bookmark was last modified in seconds since the UNIX epoch.

=head2 parent_guid

returns the guid of the bookmark's parent.

=head2 tags

returns the L<tags|https://support.mozilla.org/en-US/kb/categorizing-bookmarks-make-them-easy-to-find> associated with the bookmark as a list.

=head2 title

returns the title of the bookmark.  This can be for a folder or a bookmark.

=head2 TO_JSON

required to allow L<JSON serialisation|https://metacpan.org/pod/JSON#OBJECT-SERIALISATION> to work correctly.  This method should not need to be called directly.

=head2 type

returns an integer describing the type of the bookmark.  This can be L<BOOKMARK|/BOOKMARK>, L<FOLDER|/FOLDER> or L<SEPARATOR|/SEPARATOR>.

=head2 url

returns the URL of the bookmark.  It will be returned as a L<URL|URI::URL> object.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Bookmark requires no configuration files or environment variables.

=head1 DEPENDENCIES

Firefox::Marionette::Bookmark requires the following non-core Perl modules
 
=over
 
=item *
L<URI::data|URI::data>

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
