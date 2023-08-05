package Firefox::Marionette::Cache;

use strict;
use warnings;
use Exporter();
*import = \&Exporter::import;
our @EXPORT_OK = qw(
  CLEAR_COOKIES
  CLEAR_NETWORK_CACHE
  CLEAR_IMAGE_CACHE
  CLEAR_DOWNLOADS
  CLEAR_PASSWORDS
  CLEAR_MEDIA_DEVICES
  CLEAR_DOM_QUOTA
  CLEAR_PREDICTOR_NETWORK_DATA
  CLEAR_DOM_PUSH_NOTIFICATIONS
  CLEAR_HISTORY
  CLEAR_SESSION_HISTORY
  CLEAR_AUTH_TOKENS
  CLEAR_AUTH_CACHE
  CLEAR_PERMISSIONS
  CLEAR_CONTENT_PREFERENCES
  CLEAR_HSTS
  CLEAR_EME
  CLEAR_REPORTS
  CLEAR_STORAGE_ACCESS
  CLEAR_CERT_EXCEPTIONS
  CLEAR_CONTENT_BLOCKING_RECORDS
  CLEAR_CSS_CACHE
  CLEAR_PREFLIGHT_CACHE
  CLEAR_CLIENT_AUTH_REMEMBER_SERVICE
  CLEAR_CREDENTIAL_MANAGER_STATE
  CLEAR_ALL
  CLEAR_ALL_CACHES
  CLEAR_DOM_STORAGES
  CLEAR_FORGET_ABOUT_SITE
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK, );

our $VERSION = '1.43';

sub CLEAR_COOKIES                      { return 1 }
sub CLEAR_NETWORK_CACHE                { return 2 }
sub CLEAR_IMAGE_CACHE                  { return 4 }
sub CLEAR_DOWNLOADS                    { return 16 }
sub CLEAR_PASSWORDS                    { return 32 }
sub CLEAR_MEDIA_DEVICES                { return 64 }
sub CLEAR_DOM_QUOTA                    { return 128 }
sub CLEAR_PREDICTOR_NETWORK_DATA       { return 256 }
sub CLEAR_DOM_PUSH_NOTIFICATIONS       { return 512 }
sub CLEAR_HISTORY                      { return 1024 }
sub CLEAR_SESSION_HISTORY              { return 2048 }
sub CLEAR_AUTH_TOKENS                  { return 4096 }
sub CLEAR_AUTH_CACHE                   { return 8192 }
sub CLEAR_PERMISSIONS                  { return 16_384 }
sub CLEAR_CONTENT_PREFERENCES          { return 32_768 }
sub CLEAR_HSTS                         { return 65_536 }
sub CLEAR_EME                          { return 131_072 }
sub CLEAR_REPORTS                      { return 262_144 }
sub CLEAR_STORAGE_ACCESS               { return 524_288 }
sub CLEAR_CERT_EXCEPTIONS              { return 1_048_576 }
sub CLEAR_CONTENT_BLOCKING_RECORDS     { return 2_097_152 }
sub CLEAR_CSS_CACHE                    { return 4_194_304 }
sub CLEAR_PREFLIGHT_CACHE              { return 8_388_608 }
sub CLEAR_CLIENT_AUTH_REMEMBER_SERVICE { return 16_777_216 }
sub CLEAR_CREDENTIAL_MANAGER_STATE     { return 16_777_216 }
sub CLEAR_ALL                          { return 0xFFFFFFFF }

sub CLEAR_ALL_CACHES {
    return CLEAR_NETWORK_CACHE() | CLEAR_IMAGE_CACHE() | CLEAR_CSS_CACHE() |
      CLEAR_PREFLIGHT_CACHE() | CLEAR_HSTS();
}

sub CLEAR_DOM_STORAGES {
    return CLEAR_DOM_QUOTA() | CLEAR_DOM_PUSH_NOTIFICATIONS() | CLEAR_REPORTS();
}

sub CLEAR_FORGET_ABOUT_SITE {
    return CLEAR_HISTORY() | CLEAR_SESSION_HISTORY() | CLEAR_ALL_CACHES() |
      CLEAR_COOKIES() | CLEAR_EME() | CLEAR_DOWNLOADS() | CLEAR_PERMISSIONS() |
      CLEAR_DOM_STORAGES() | CLEAR_CONTENT_PREFERENCES() |
      CLEAR_PREDICTOR_NETWORK_DATA() | CLEAR_DOM_PUSH_NOTIFICATIONS() |
      CLEAR_CLIENT_AUTH_REMEMBER_SERVICE() | CLEAR_REPORTS() |
      CLEAR_CERT_EXCEPTIONS() | CLEAR_CREDENTIAL_MANAGER_STATE();
}

1;    # Magic true value required at end of module
__END__
=head1 NAME

Firefox::Marionette::Cache - Constants to describe actions on the cache

=head1 VERSION

Version 1.43

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Firefox::Marionette::Cache qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->go('https://google.com'); # where is a good site to produce a lot of cookies?

    $firefox->go('about:blank');

    $firefox->clear_cache(CLEAR_COOKIES());

=head1 DESCRIPTION

This module handles the implementation of the Firefox cache constants.  This is sourced from L<toolkit/components/cleardata/nsIClearDataService.idl|https://hg.mozilla.org/mozilla-central/file/tip/toolkit/components/cleardata/nsIClearDataService.idl>

=head1 CONSTANTS

=head2 CLEAR_COOKIES

returns the value of CLEAR_COOKIES, which is 1 << 0 = 1

=head2 CLEAR_NETWORK_CACHE

returns the value of CLEAR_NETWORK_CACHE, which is 1 << 1 = 2

=head2 CLEAR_IMAGE_CACHE

returns the value of CLEAR_IMAGE_CACHE, which is 1 << 2 = 4

=head2 CLEAR_DOWNLOADS

returns the value of CLEAR_DOWNLOADS, which is 1 << 4 = 16

=head2 CLEAR_PASSWORDS

returns the value of CLEAR_PASSWORDS, which is 1 << 5 = 32

=head2 CLEAR_MEDIA_DEVICES

returns the value of CLEAR_MEDIA_DEVICES, which is 1 << 6 = 64

=head2 CLEAR_DOM_QUOTA

returns the value of CLEAR_DOM_QUOTA, which is 1 << 7 = 128 (LocalStorage, IndexedDB, ServiceWorkers, DOM Cache and so on.)

=head2 CLEAR_PREDICTOR_NETWORK_DATA

returns the value of CLEAR_PREDICTOR_NETWORK_DATA, which is 1 << 8 = 256 

=head2 CLEAR_DOM_PUSH_NOTIFICATIONS

returns the value of CLEAR_DOM_PUSH_NOTIFICATIONS, which is 1 << 9 = 512

=head2 CLEAR_HISTORY

returns the value of CLEAR_HISTORY, which is 1 << 10 = 1024 (Places history)

=head2 CLEAR_SESSION_HISTORY

returns the value of CLEAR_SESSION_HISTORY, which is 1 << 11 = 2048

=head2 CLEAR_AUTH_TOKENS

returns the value of CLEAR_AUTH_TOKENS, which is 1 << 12 = 4096

=head2 CLEAR_AUTH_CACHE

returns the value of CLEAR_AUTH_CACHE, which is 1 << 13 = 8192 (Login cache)

=head2 CLEAR_PERMISSIONS

returns the value of CLEAR_PERMISSIONS, which is 1 << 14 = 16384

=head2 CLEAR_CONTENT_PREFERENCES

returns the value of CLEAR_CONTENT_PREFERENCES, which is 1 << 15 = 32768

=head2 CLEAR_HSTS

returns the value of CLEAR_HSTS, which is 1 << 16 = 65536 (HTTP Strict Transport Security data)

=head2 CLEAR_EME

returns the value of CLEAR_EME, which is 1 << 17 = 131072 (Media plugin data)

=head2 CLEAR_REPORTS

returns the value of CLEAR_REPORTS, which is 1 << 18 = 262144 (Reporting API reports)

=head2 CLEAR_STORAGE_ACCESS

returns the value of CLEAR_STORAGE_ACCESS, which is 1 << 19 = 524288 (StorageAccessAPI flag, which indicates user interaction)

=head2 CLEAR_CERT_EXCEPTIONS

returns the value of CLEAR_CERT_EXCEPTIONS, which is 1 << 20 = 1048576

=head2 CLEAR_CONTENT_BLOCKING_RECORDS

returns the value of CLEAR_CONTENT_BLOCKING_RECORDS, which is 1 << 21 = 2097152 (content blocking database)

=head2 CLEAR_CSS_CACHE

returns the value of CLEAR_CSS_CACHE, which is 1 << 22 = 4194304 (in-memory CSS cache)

=head2 CLEAR_PREFLIGHT_CACHE

returns the value of CLEAR_PREFLIGHT_CACHE, which is 1 << 23 = 8388608 (CORS preflight cache)

=head2 CLEAR_CLIENT_AUTH_REMEMBER_SERVICE

returns the value of CLEAR_CLIENT_AUTH_REMEMBER_SERVICE, which is 1 << 24 = 16777216 (clients authentification certificate)

=head2 CLEAR_CREDENTIAL_MANAGER_STATE

returns the value of CLEAR_CREDENTIAL_MANAGER_STATE, which is 1 << 24 = 16777216 (FedCM)

=head2 CLEAR_ALL

returns the value of CLEAR_ALL, which is 4294967295 (0xFFFFFFFF)

=head2 CLEAR_ALL_CACHES

returns the value of CLEAR_ALL_CACHES, which is 12648454 (L<CLEAR_NETWORK_CACHE|/CLEAR_NETWORK_CACHE> | L<CLEAR_IMAGE_CACHE|/CLEAR_IMAGE_CACHE> | L<CLEAR_CSS_CACHE|/CLEAR_CSS_CACHE> | L<CLEAR_PREFLIGHT_CACHE|/CLEAR_PREFLIGHT_CACHE> | L<CLEAR_HSTS|/CLEAR_HSTS>)

=head2 CLEAR_DOM_STORAGES

returns the value of CLEAR_DOM_STORAGES, which is 262784 (L<CLEAR_DOM_QUOTA|/CLEAR_DOM_QUOTA> | L<CLEAR_DOM_PUSH_NOTIFICATIONS|/CLEAR_DOM_PUSH_NOTIFICATIONS> | L<CLEAR_REPORTS|/CLEAR_REPORTS>)

=head2 CLEAR_FORGET_ABOUT_SITE

returns the value of CLEAR_FORGET_ABOUT_SITE, which is 30920599 (L<CLEAR_HISTORY|/CLEAR_HISTORY> | L<CLEAR_SESSION_HISTORY|/CLEAR_SESSION_HISTORY> | L<CLEAR_ALL_CACHES|/CLEAR_ALL_CACHES> | L<CLEAR_COOKIES|/CLEAR_COOKIES> | L<CLEAR_EME|/CLEAR_EME> | L<CLEAR_DOWNLOADS|/CLEAR_DOWNLOADS> | L<CLEAR_PERMISSIONS|/CLEAR_PERMISSIONS> | L<CLEAR_DOM_STORAGES|/CLEAR_DOM_STORAGES> | L<CLEAR_CONTENT_PREFERENCES|/CLEAR_CONTENT_PREFERENCES> | L<CLEAR_PREDICTOR_NETWORK_DATA|/CLEAR_PREDICTOR_NETWORK_DATA> | L<CLEAR_DOM_PUSH_NOTIFICATIONS|/CLEAR_DOM_PUSH_NOTIFICATIONS> | L<CLEAR_CLIENT_AUTH_REMEMBER_SERVICE|/CLEAR_CLIENT_AUTH_REMEMBER_SERVICE> | L<CLEAR_REPORTS|/CLEAR_REPORTS> | L<CLEAR_CERT_EXCEPTIONS|/CLEAR_CERT_EXCEPTIONS> | L<CLEAR_CREDENTIAL_MANAGER_STATE|/CLEAR_CREDENTIAL_MANAGER_STATE>)

=head1 SUBROUTINES/METHODS

None.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Cache requires no configuration files or environment variables.

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
