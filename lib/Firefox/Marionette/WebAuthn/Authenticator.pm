package Firefox::Marionette::WebAuthn::Authenticator;

use strict;
use warnings;

our $VERSION = '1.63';

sub BLE        { return 'ble' }
sub CTAP1_U2F  { return 'ctap1/u2f' }
sub CTAP2      { return 'ctap2' }
sub CTAP2_1    { return 'ctap2_1' }
sub HYBRID     { return 'hybrid' }
sub INTERNAL   { return 'internal' }
sub NFC        { return 'nfc' }
sub SMART_CARD { return 'smart-card' }
sub USB        { return 'usb' }

sub new {
    my ( $class, %parameters ) = @_;
    my $self = bless {%parameters}, $class;
    return $self;
}

sub id {
    my ($self) = @_;
    return $self->{id};
}

sub protocol {
    my ($self) = @_;
    return $self->{protocol};
}

sub transport {
    my ($self) = @_;
    return $self->{transport};
}

sub has_resident_key {
    my ($self) = @_;
    return $self->{has_resident_key};
}

sub has_user_verification {
    my ($self) = @_;
    return $self->{has_user_verification};
}

sub is_user_consenting {
    my ($self) = @_;
    return $self->{is_user_consenting};
}

sub is_user_verified {
    my ($self) = @_;
    return $self->{is_user_verified};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::WebAuthn::Authenticator - Represents a Firefox WebAuthn Authenticator

=head1 VERSION

Version 1.63

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Crypt::URandom();

    my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('register-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });

=head1 DESCRIPTION

This module handles the implementation of a L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators> using the Marionette protocol.

=head1 CONSTANTS

=head2 BLE

return 'ble', the L<transport|/transport> code for a L<Bluetooth Low Energy|https://en.wikipedia.org/wiki/Bluetooth_Low_Energy> transport.

=head2 CTAP1_U2F

returns 'ctap1/u2f', the L<protocol|/protocol> code for an older version of L<Client to Authenticator Protocol|https://en.wikipedia.org/wiki/Client_to_Authenticator_Protocol>, that is backwards compatible with the L<Universal 2nd Factor|https://en.wikipedia.org/wiki/Universal_2nd_Factor> open standard.

=head2 CTAP2

returns 'ctap2', the L<protocol|/protocol> code for the L<Client to Authenticator Protocol|https://en.wikipedia.org/wiki/Client_to_Authenticator_Protocol>.

=head2 CTAP2_1

returns 'ctap2_1', the L<protocol|/protocol> code for the next version of the L<Client to Authenticator Protocol|https://en.wikipedia.org/wiki/Client_to_Authenticator_Protocol>.

=head2 HYBRID

returns 'hybrid', the L<transport|/transport> code for a L<hybrid|https://w3c.github.io/webauthn/#dom-authenticatortransport-hybrid> transport.

=head2 INTERNAL

returns 'internal', the L<transport|/transport> code for an L<internal|https://w3c.github.io/webauthn/#dom-authenticatortransport-internal> transport.

=head2 NFC

return 'nfc', the L<transport|/transport> code for a L<Near-field communication|https://en.wikipedia.org/wiki/Near-field_communication> transport.

=head2 SMART_CARD

returns 'smart-card', the L<transport|/transport> code for a L<ISO/IEC 7816|https://en.wikipedia.org/wiki/ISO/IEC_7816> L<Smart Card|https://w3c.github.io/webauthn/#dom-authenticatortransport-smart-card> transport.

=head2 USB

return 'usb', the L<transport|/transport> code for a L<Universal Serial Bus|https://en.wikipedia.org/wiki/USB> transport.

=head1 SUBROUTINES/METHODS

=head2 new

accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * has_resident_key - boolean value to indicate if the L<authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators> will support L<client side discoverable credentials|https://www.w3.org/TR/webauthn-2/#client-side-discoverable-credential>

=item * has_user_verification - boolean value to determine if the L<authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators> supports L<user verification|https://www.w3.org/TR/webauthn-2/#user-verification>.

=item * id - the id of the authenticator.

=item * is_user_consenting - boolean value to determine the result of all L<user consent|https://www.w3.org/TR/webauthn-2/#user-consent> L<authorization gestures|https://www.w3.org/TR/webauthn-2/#authorization-gesture>, and by extension, any L<test of user presence|https://www.w3.org/TR/webauthn-2/#test-of-user-presence> performed on the L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators>. If set to true, a L<user consent|https://www.w3.org/TR/webauthn-2/#user-consent> will always be granted. If set to false, it will not be granted.

=item * is_user_verified - boolean value to determine the result of L<User Verification|https://www.w3.org/TR/webauthn-2/#user-verification> performed on the L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators>. If set to true, L<User Verification|https://www.w3.org/TR/webauthn-2/#user-verification> will always succeed. If set to false, it will fail.

=item * protocol - the L<protocol|/protocol> spoken by the authenticator.  This may be L<CTAP1_U2F|/CTAP1_U2F>, L<CTAP2|/CTAP2> or L<CTAP2_1|/CTAP2_1>.

=item * transport - the L<transport|/transport> simulated by the authenticator.  This may be L<BLE|/BLE>, L<HYBRID|/HYBRID>, L<INTERNAL|/INTERNAL>, L<NFC|/NFC>, L<SMART_CARD|/SMART_CARD> or L<USB|/USB>.

=back

This method returns a new L<webauthn virtual authenticator|Firefox::Marionette::WebAuthn::Authenticator> object.

=head2 has_resident_key

This method returns a boolean value to indicate if the L<authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators> will support L<client side discoverable credentials|https://www.w3.org/TR/webauthn-2/#client-side-discoverable-credential>.

=head2 has_user_verification

This method returns a boolean value to determine if the L<authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators> supports L<user verification|https://www.w3.org/TR/webauthn-2/#user-verification>.

=head2 is_user_consenting

This method returns a boolean value to determine the result of all L<user consent|https://www.w3.org/TR/webauthn-2/#user-consent> L<authorization gestures|https://www.w3.org/TR/webauthn-2/#authorization-gesture>, and by extension, any L<test of user presence|https://www.w3.org/TR/webauthn-2/#test-of-user-presence> performed on the L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators>. If set to true, a L<user consent|https://www.w3.org/TR/webauthn-2/#user-consent> will always be granted. If set to false, it will not be granted.

=head2 is_user_verified

This method returns a boolean value to determine the result of L<User Verification|https://www.w3.org/TR/webauthn-2/#user-verification> performed on the L<Virtual Authenticator|https://www.w3.org/TR/webauthn-2/#virtual-authenticators>. If set to true, L<User Verification|https://www.w3.org/TR/webauthn-2/#user-verification> will always succeed. If set to false, it will fail.

=head2 protocol

This method returns a string containing the L<protocol|/protocol> spoken by the authenticator.  This may be L<CTAP1_U2F|/CTAP1_U2F>, L<CTAP2|/CTAP2> or L<CTAP2_1|/CTAP2_1>.

=head2 transport

This method returns a string containing the L<transport|/transport> simulated by the authenticator.  This may be L<BLE|/BLE>, L<HYBRID|/HYBRID>, L<INTERNAL|/INTERNAL>, L<NFC|/NFC>, L<SMART_CARD|/SMART_CARD> or L<USB|/USB>.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::WebAuthn::Authenticator requires no configuration files or environment variables.

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
