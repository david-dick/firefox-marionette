package Waterfox::Marionette::Profile;

use strict;
use warnings;
use English qw( -no_match_vars );
use File::Spec();
use parent qw(Firefox::Marionette::Profile);

BEGIN {
    if ( $OSNAME eq 'MSWin32' ) {
        require Win32;
    }
}
our $VERSION = '1.32';

sub profile_ini_directory {
    my ($class) = @_;
    my $profile_ini_directory;
    if ( $OSNAME eq 'darwin' ) {
        my $home_directory =
          ( getpwuid $EFFECTIVE_USER_ID )
          [ $class->SUPER::_GETPWUID_DIR_INDEX() ];
        defined $home_directory
          or Firefox::Marionette::Exception->throw(
            "Failed to execute getpwuid for $OSNAME:$EXTENDED_OS_ERROR");
        $profile_ini_directory = File::Spec->catdir( $home_directory, 'Library',
            'Application Support', 'Waterfox' );
    }
    elsif ( $OSNAME eq 'MSWin32' ) {
        $profile_ini_directory =
          File::Spec->catdir( Win32::GetFolderPath( Win32::CSIDL_APPDATA() ),
            'Waterfox', 'Waterfox' );
    }
    elsif ( $OSNAME eq 'cygwin' ) {
        $profile_ini_directory =
          File::Spec->catdir( $ENV{APPDATA}, 'Waterfox', 'Waterfox' );
    }
    else {
        my $home_directory =
          ( getpwuid $EFFECTIVE_USER_ID )
          [ $class->SUPER::_GETPWUID_DIR_INDEX() ];
        defined $home_directory
          or Firefox::Marionette::Exception->throw(
            "Failed to execute getpwuid for $OSNAME:$EXTENDED_OS_ERROR");
        $profile_ini_directory =
          File::Spec->catdir( $home_directory, '.waterfox' );
    }
    return $profile_ini_directory;
}

sub new {
    my ( $class, %parameters ) = @_;
    my $profile = bless { comments => q[], keys => {} }, $class;
    $profile->set_value( 'bookmarks.initialized.pref', 'true', 0 );
    $profile->set_value( 'browser.bookmarks.restore_default_bookmarks',
        'false', 0 );
    $profile->set_value( 'browser.download.useDownloadDir', 'true', 0 );
    $profile->set_value( 'browser.download.folderList',     2,      0 )
      ;    # the last folder specified for a download
    $profile->set_value( 'browser.places.importBookmarksHTML',  'true',  0 );
    $profile->set_value( 'browser.reader.detectedFirstArticle', 'true',  0 );
    $profile->set_value( 'browser.shell.checkDefaultBrowser',   'false', 0 );
    $profile->set_value( 'browser.showQuitWarning',             'false', 0 );
    $profile->set_value( 'browser.startup.homepage', 'about:blank',      1 );
    $profile->set_value( 'browser.startup.homepage_override.mstone',
        'ignore', 1 );
    $profile->set_value( 'browser.startup.page',           '0',      0 );
    $profile->set_value( 'browser.tabs.warnOnClose',       'false',  0 );
    $profile->set_value( 'browser.warnOnQuit',             'false',  0 );
    $profile->set_value( 'devtools.jsonview.enabled',      'false',  0 );
    $profile->set_value( 'devtools.netmonitor.persistlog', 'true',   0 );
    $profile->set_value( 'devtools.toolbox.host',          'window', 1 );
    $profile->set_value( 'dom.disable_open_click_delay',   0,        0 );
    $profile->set_value( 'extensions.installDistroAddons', 'false',  0 );
    $profile->set_value( 'focusmanager.testmode',          'true',   0 );
    $profile->set_value( 'marionette.port', $class->SUPER::ANY_PORT() );
    $profile->set_value( 'network.http.prompt-temp-redirect',    'false', 0 );
    $profile->set_value( 'network.http.request.max-start-delay', '0',     0 );
    $profile->set_value( 'security.osclientcerts.autoload',      'true',  0 );
    $profile->set_value( 'signon.autofillForms',                 'false', 0 );
    $profile->set_value( 'signon.rememberSignons',               'false', 0 );
    $profile->set_value( 'startup.homepage_welcome_url', 'about:blank',   1 );
    $profile->set_value( 'startup.homepage_welcome_url.additional',
        'about:blank', 1 );

    if ( !$parameters{chatty} ) {
        $profile->set_value( 'app.update.auto',             'false', 0 );
        $profile->set_value( 'app.update.staging.enabled',  'false', 0 );
        $profile->set_value( 'app.update.checkInstallTime', 'false', 0 );
    }

    return $profile;
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Waterfox::Marionette::Profile - Represents a prefs.js Waterfox Profile

=head1 VERSION

Version 1.32

=head1 SYNOPSIS

    use Waterfox::Marionette();
    use v5.10;

    my $profile = Waterfox::Marionette::Profile->new();

    $profile->set_value('browser.startup.homepage', 'https://duckduckgo.com');

    my $firefox = Waterfox::Marionette->new(profile => $profile);
	
    $firefox->quit();
	
    foreach my $profile_name (Waterfox::Marionette::Profile->names()) {
        # start firefox using a specific existing profile
        $firefox = Waterfox::Marionette->new(profile_name => $profile_name);
        $firefox->quit();

        # OR start a new browser with a copy of a specific existing profile

        $profile = Waterfox::Marionette::Profile->existing($profile_name);
        $firefox = Waterox::Marionette->new(profile => $profile);
        $firefox->quit();
    }

=head1 DESCRIPTION

This module handles the implementation of a C<prefs.js> Waterfox Profile.  This module inherits from L<Firefox::Marionette::Profile|Firefox::Marionette::Profile>.

=head1 SUBROUTINES/METHODS

For a full list of methods available, see L<Firefox::Marionette::Profile|Firefox::Marionette::Profile#SUBROUTINES/METHODS>

=head2 new

returns a new L<profile|Waterfox::Marionette::Profile>.

=head2 profile_ini_directory

returns the base directory for profiles.

=head1 DIAGNOSTICS

See L<Firefox::Marionette::Profile|Firefox::Marionette::Profile>.

=head1 CONFIGURATION AND ENVIRONMENT

Waterfox::Marionette::Profile requires no configuration files or environment variables.

=head1 DEPENDENCIES

Waterfox::Marionette::Profile requires no non-core Perl modules
 
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
