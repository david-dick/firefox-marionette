package Firefox::Marionette::WebAuthn::Credential;

use strict;
use warnings;

our $VERSION = '1.69';

my %key_mapping = (
    isResidentCredential => 'is_resident',
    rpId                 => 'host',
    signCount            => 'sign_count',
    userHandle           => 'user',
    privateKey           => 'private_key',
    credentialId         => 'id',
);

sub new {
    my ( $class, %parameters ) = @_;
    my $self = bless {}, $class;
    foreach my $key_name ( sort { $a cmp $b } keys %key_mapping ) {
        if ( exists $parameters{ $key_mapping{$key_name} } ) {
            $self->{ $key_mapping{$key_name} } =
              $parameters{ $key_mapping{$key_name} };
        }
        elsif ( exists $parameters{$key_name} ) {
            $self->{ $key_mapping{$key_name} } = $parameters{$key_name};
        }
    }
    return $self;
}

sub id {
    my ($self) = @_;
    return $self->{id};
}

sub host {
    my ($self) = @_;
    return $self->{host};
}

sub is_resident {
    my ($self) = @_;
    return $self->{is_resident};
}

sub private_key {
    my ($self) = @_;
    return $self->{private_key};
}

sub sign_count {
    my ($self) = @_;
    return $self->{sign_count};
}

sub user {
    my ($self) = @_;
    return $self->{user};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::WebAuthn::Credential - Represents a Firefox WebAuthn Credential

=head1 VERSION

Version 1.69

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Crypt::URandom();

    my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
    my $firefox = Firefox::Marionette->new();
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('register-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });
    foreach my $credential ($firefox->webauthn_credentials()) {
        $firefox->delete_webauthn_credential($credential);

# ... time passes ...

        $firefox->add_webauthn_credential(
                  id            => $credential->id(),
                  host          => $credential->host(),
                  user          => $credential->user(),
                  private_key   => $credential->private_key(),
                  is_resident   => $credential->is_resident(),
                  sign_count    => $credential->sign_count(),
                              );
    }
    $firefox->go('about:blank');
    $firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_COOKIES());
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });

=head1 DESCRIPTION

This module handles the implementation of a single WebAuth Credential using the Marionette protocol.

=head1 SUBROUTINES/METHODS

=head2 new

accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * host - contains the domain that this credential is to be used for.  In the language of L<WebAuthn|https://www.w3.org/TR/webauthn-2>, this field is referred to as the L<relying party identifier|https://www.w3.org/TR/webauthn-2/#relying-party-identifier> or L<RP ID|https://www.w3.org/TR/webauthn-2/#rp-id>.

=item * id - contains the unique id for this credential, also known as the L<Credential ID|https://www.w3.org/TR/webauthn-2/#credential-id>.

=item * is_resident - contains a boolean that if set to true, a L<client-side discoverable credential|https://w3c.github.io/webauthn/#client-side-discoverable-credential> is to be created. If set to false, a L<server-side credential|https://w3c.github.io/webauthn/#server-side-credential> is to be created instead.

=item * private_key - either a L<RFC5958|https://www.rfc-editor.org/rfc/rfc5958> encoded private key encoded using L<encode_base64url|MIME::Base64#encode_base64url(-$bytes-)> or a hash containing the following keys;

=over 8

=item * name - contains the name of the private key algorithm, such as "RSA-PSS" (the default), "RSASSA-PKCS1-v1_5", "ECDSA" or "ECDH".

=item * size - contains the modulus length of the private key.  This is only valid for "RSA-PSS" or "RSASSA-PKCS1-v1_5" private keys.

=item * hash - contains the name of the hash algorithm, such as "SHA-512" (the default).  This is only valid for "RSA-PSS" or "RSASSA-PKCS1-v1_5" private keys.

=item * curve - contains the name of the curve for the private key, such as "P-384" (the default).  This is only valid for "ECDSA" or "ECDH" private keys.

=back

=item * sign_count - contains the initial value for a L<signature counter|https://w3c.github.io/webauthn/#signature-counter> associated to the L<public key credential source|https://w3c.github.io/webauthn/#public-key-credential-source>.

=item * user - contains the L<userHandle|https://w3c.github.io/webauthn/#public-key-credential-source-userhandle> associated to the credential encoded using L<encode_base64url|MIME::Base64#encode_base64url(-$bytes-)>.  This property is optional.

=back

This method returns a new L<Firefox::Marionette::WebAuthn::Credential|Firefox::Marionette::WebAuthn::Credential> object.

=head2 host

returns the domain that this credential is to be used for.  In the language of L<WebAuthn|https://www.w3.org/TR/webauthn-2>, this field is referred to as the L<relying party identifier|https://www.w3.org/TR/webauthn-2/#relying-party-identifier> or L<RP ID|https://www.w3.org/TR/webauthn-2/#rp-id>.

=head2 is_resident

returns a boolean that if true, a L<client-side discoverable credential|https://w3c.github.io/webauthn/#client-side-discoverable-credential> is to be created. If false, a L<server-side credential|https://w3c.github.io/webauthn/#server-side-credential> is to be created instead.

=head2 private_key

returns a L<RFC5958|https://www.rfc-editor.org/rfc/rfc5958> encoded private key encoded using L<encode_base64url|MIME::Base64#encode_base64url(-$bytes-)>.

=head2 sign_count

returns the L<signature counter|https://w3c.github.io/webauthn/#signature-counter> associated to the L<public key credential source|https://w3c.github.io/webauthn/#public-key-credential-source>.

=head2 user

returns the L<userHandle|https://w3c.github.io/webauthn/#public-key-credential-source-userhandle> associated to the credential encoded using L<encode_base64url|MIME::Base64#encode_base64url(-$bytes-)>.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::WebAuthn::Credential requires no configuration files or environment variables.

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
