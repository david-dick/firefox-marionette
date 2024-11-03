package Firefox::Marionette::DNS;

use strict;
use warnings;
use Exporter();
*import = \&Exporter::import;
our @EXPORT_OK = qw(
  RESOLVE_TYPE_DEFAULT
  RESOLVE_TYPE_TXT
  RESOLVE_TYPE_HTTPSSVC
  RESOLVE_BYPASS_CACHE
  RESOLVE_CANONICAL_NAME
  RESOLVE_PRIORITY_MEDIUM
  RESOLVE_PRIORITY_LOW
  RESOLVE_SPECULATE
  RESOLVE_DISABLE_IPV6
  RESOLVE_OFFLINE
  RESOLVE_DISABLE_IPV4
  RESOLVE_ALLOW_NAME_COLLISION
  RESOLVE_DISABLE_TRR
  RESOLVE_REFRESH_CACHE
  RESOLVE_TRR_MODE_MASK
  RESOLVE_TRR_DISABLED_MODE
  RESOLVE_IGNORE_SOCKS_DNS
  RESOLVE_IP_HINT
  RESOLVE_WANT_RECORD_ON_ERROR
  RESOLVE_DISABLE_NATIVE_HTTPS_QUERY
  RESOLVE_CREATE_MOCK_HTTPS_RR
  ALL_DNSFLAGS_BITS
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK, );

our $VERSION = '1.62';

sub RESOLVE_TYPE_DEFAULT               { return 0 }
sub RESOLVE_TYPE_TXT                   { return 16 }
sub RESOLVE_TYPE_HTTPSSVC              { return 65 }
sub RESOLVE_DEFAULT_FLAGS              { return 0 }
sub RESOLVE_BYPASS_CACHE               { return 1 }
sub RESOLVE_CANONICAL_NAME             { return 2 }
sub RESOLVE_PRIORITY_MEDIUM            { return 4 }
sub RESOLVE_PRIORITY_LOW               { return 8 }
sub RESOLVE_SPECULATE                  { return 16 }
sub RESOLVE_DISABLE_IPV6               { return 32 }
sub RESOLVE_OFFLINE                    { return 64 }
sub RESOLVE_DISABLE_IPV4               { return 128 }
sub RESOLVE_ALLOW_NAME_COLLISION       { return 256 }
sub RESOLVE_DISABLE_TRR                { return 512 }
sub RESOLVE_REFRESH_CACHE              { return 1024 }
sub RESOLVE_TRR_MODE_MASK              { return 6144 }
sub RESOLVE_TRR_DISABLED_MODE          { return 2048 }
sub RESOLVE_IGNORE_SOCKS_DNS           { return 8192 }
sub RESOLVE_IP_HINT                    { return 16_384 }
sub RESOLVE_WANT_RECORD_ON_ERROR       { return 65_536 }
sub RESOLVE_DISABLE_NATIVE_HTTPS_QUERY { return 131_072 }
sub RESOLVE_CREATE_MOCK_HTTPS_RR       { return 262_144 }
sub ALL_DNSFLAGS_BITS                  { return 524_287 }

1;    # Magic true value required at end of module
__END__
=head1 NAME

Firefox::Marionette::DNS - Constants for calls to the resolve method

=head1 VERSION

Version 1.62

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Firefox::Marionette::DNS qw(:all);
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    foreach my $address ($firefox->resolve('metacpan.org', type => RESOLVE_TYPE_DEFAULT(), flags => RESOLVE_BYPASS_CACHE())) {
       ...
    }

=head1 DESCRIPTION

This module handles the implementation of the Firefox Marionette DNS constants

=head1 CONSTANTS

=head2 RESOLVE_TYPE_DEFAULT

returns the value of RESOLVE_TYPE_DEFAULT, which is 0, this is the standard L<A|https://en.wikipedia.org/wiki/List_of_DNS_record_types#A>/L<AAAA|https://en.wikipedia.org/wiki/List_of_DNS_record_types#AAAA> lookup.

=head2 RESOLVE_TYPE_TXT

returns the value of RESOLVE_TYPE_TXT, which is 1 << 4 = 16, this is a L<TXT|https://en.wikipedia.org/wiki/TXT_record> lookup.

=head2 RESOLVE_TYPE_HTTPSSVC = 65,

returns the value of RESOLVE_TYPE_HTTPSSVC, which is 65, this is L<Service Binding and Parameter Specification via DNS|https://datatracker.ietf.org/doc/rfc9460/>.

=head2 RESOLVE_DEFAULT_FLAGS

returns the value of RESOLVE_DEFAULT_FLAGS, which is 0, this is the default.

=head2 RESOLVE_BYPASS_CACHE

returns the value of RESOLVE_BYPASS_CACHE, which is 1 << 0 = 1, this suppresses the internal DNS lookup cache.

=head2 RESOLVE_CANONICAL_NAME

returns the value of RESOLVE_CANONICAL_NAME, which is 1 << 1 = 2, this queries the canonical name of the specified host.

=head2 RESOLVE_PRIORITY_MEDIUM

returns the value of RESOLVE_PRIORITY_MEDIUM, which is 1 << 2 = 4, this gives the query lower priority.

=head2 RESOLVE_PRIORITY_LOW

returns the value of RESOLVE_PRIORITY_LOW, which is 1 << 3 = 8, this gives the query lower priority still.

=head2 RESOLVE_SPECULATE

returns the value of RESOLVE_SPECULATE, which is 1 << 4 = 16, indicates request is speculative. Speculative requests return errors if prefetching is disabled by configuration.

=head2 RESOLVE_DISABLE_IPV6

returns the value of RESOLVE_DISABLE_IPV6, which is 1 << 5 = 32, this only returns IPv4 addresses.

=head2 RESOLVE_OFFLINE

return 64, only literals and cached entries will be returned.

=head2 RESOLVE_DISABLE_IPV4

returns 128, only IPv6 addresses will be returned from resolve/asyncResolve.

=head2 RESOLVE_ALLOW_NAME_COLLISION

returns the value of RESOLVE_ALLOW_NAME_COLLISION, which is 1 << 8 = 256, this allows name collision results (127.0.53.53) which are normally filtered.

=head2 RESOLVE_DISABLE_TRR

returns the value of RESOLVE_DISABLE_TRR, which is 1 << 9 = 512, this stops using TRR for resolving the host name.

=head2 RESOLVE_REFRESH_CACHE

returns the value of RESOLVE_REFRESH_CACHE, which is 1 << 10 = 1024, when set (together with L<RESOLVE_BYPASS_CACHE|/RESOLVE_BYPASS_CACHE>), invalidate the DNS existing cache entry first (if existing) then make a new resolve.

=head2 RESOLVE_TRR_MODE_MASK

returns the value of RESOLVE_TRR_MODE_MASK, which is ((1 << 11) | (1 << 12)) = 6144, these two bits encode the TRR mode of the request

=head2 RESOLVE_TRR_DISABLED_MODE

returns the value of RESOLVE_TRR_DISABLED_MODE, which is 1 << 11 = 2048.

=head2 RESOLVE_IGNORE_SOCKS_DNS

returns the value of RESOLVE_IGNORE_SOCKS_DNS, which is 1 << 13 = 8192, this will orce resolution even when SOCKS proxy with DNS forwarding is configured.  Only to be used for the proxy host resolution.

=head2 RESOLVE_IP_HINT

returns the value of RESOLVE_IP_HINT, which is 1 << 14 = 16384, this will only return cached IP hint addresses from L<resolve|Firefox::Marionette#resolve>.

=head2 RESOLVE_WANT_RECORD_ON_ERROR

returns the value of RESOLVE_WANT_RECORD_ON_ERROR, which is 1 << 16 = 65536, this will pass a DNS record to even when there was a resolution error.

=head2 RESOLVE_DISABLE_NATIVE_HTTPS_QUERY

returns the value of RESOLVE_DISABLE_NATIVE_HTTPS_QUERY, which is 1 << 17 = 131072, this disables the native HTTPS queries.

=head2 RESOLVE_CREATE_MOCK_HTTPS_RR

returns the value of RESOLVE_CREATE_MOCK_HTTPS_RR, which is 1 << 18 = 262144, this creates a mock HTTPS RR and use it.  This is only for testing purposes

=head2 ALL_DNSFLAGS_BITS

returns the value of ALL_DNSFLAGS_BITS, which is ((1 << 19) - 1) = 524287, this is all flags turned on.

=head1 SUBROUTINES/METHODS

None.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::DNS requires no configuration files or environment variables.

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
