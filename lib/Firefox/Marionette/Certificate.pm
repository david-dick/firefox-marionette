package Firefox::Marionette::Certificate;

use strict;
use warnings;

our $VERSION = '1.58';

sub _NUMBER_OF_MICROSECOND_DIGITS { return -6 }

sub new {
    my ( $class, $parameters ) = @_;

    my $self = bless { %{$parameters} }, $class;
    return $self;
}

sub issuer_name {
    my ($self) = @_;
    return $self->{issuerName};
}

sub common_name {
    my ($self) = @_;
    return $self->{commonName};
}

sub _cert_type {
    my ($self) = @_;
    return $self->{certType};
}

sub _bitwise_and_with_cert_type {
    my ( $self, $argument ) = @_;
    if ( defined $self->_cert_type() ) {
        return $argument & $self->_cert_type();
    }
    return;
}

sub is_any_cert {
    my ($self) = @_;
    return $self->_bitwise_and_with_cert_type( $self->{ANY_CERT} );
}

sub email_address {
    my ($self) = @_;
    return $self->{emailAddress} eq '(no email address)'
      ? undef
      : $self->{emailAddress};
}

sub sha256_subject_public_key_info_digest {
    my ($self) = @_;
    return $self->{sha256SubjectPublicKeyInfoDigest};
}

sub issuer_organization {
    my ($self) = @_;
    return $self->{issuerOrganization};
}

sub db_key {
    my ($self) = @_;
    return $self->{dbKey};
}

sub is_unknown_cert {
    my ($self) = @_;
    return $self->_bitwise_and_with_cert_type( $self->{UNKNOWN_CERT} );
}

sub is_built_in_root {
    my ($self) = @_;
    return $self->{isBuiltInRoot};
}

sub token_name {
    my ($self) = @_;
    return $self->{tokenName};
}

sub sha256_fingerprint {
    my ($self) = @_;
    return $self->{sha256Fingerprint};
}

sub is_server_cert {
    my ($self) = @_;
    return $self->_bitwise_and_with_cert_type( $self->{SERVER_CERT} );
}

sub is_user_cert {
    my ($self) = @_;
    return $self->_bitwise_and_with_cert_type( $self->{USER_CERT} );
}

sub subject_name {
    my ($self) = @_;
    return $self->{subjectName};
}

sub key_usages {
    my ($self) = @_;
    return $self->{keyUsages};
}

sub is_ca_cert {
    my ($self) = @_;
    return $self->_bitwise_and_with_cert_type( $self->{CA_CERT} );
}

sub issuer_organization_unit {
    my ($self) = @_;
    return $self->{issuerOrganizationUnit};
}

sub _convert_time_to_seconds {
    my ( $self, $microseconds ) = @_;
    my $seconds = substr $microseconds, 0, _NUMBER_OF_MICROSECOND_DIGITS();
    return $seconds + 0;
}

sub not_valid_after {
    my ($self) = @_;
    return $self->_convert_time_to_seconds( $self->{validity}->{notAfter} );
}

sub not_valid_before {
    my ($self) = @_;
    return $self->_convert_time_to_seconds( $self->{validity}->{notBefore} );
}

sub serial_number {
    my ($self) = @_;
    return $self->{serialNumber};
}

sub is_email_cert {
    my ($self) = @_;
    return $self->_bitwise_and_with_cert_type( $self->{EMAIL_CERT} );
}

sub issuer_common_name {
    my ($self) = @_;
    return $self->{issuerCommonName};
}

sub organization {
    my ($self) = @_;
    return $self->{organization};
}

sub nickname {
    my ($self) = @_;
    return $self->{nickname};
}

sub sha1_fingerprint {
    my ($self) = @_;
    return $self->{sha1Fingerprint};
}

sub display_name {
    my ($self) = @_;
    return $self->{displayName};
}

sub organizational_unit {
    my ($self) = @_;
    return $self->{organizationalUnit};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Certificate - Represents a x509 Certificate from Firefox

=head1 VERSION

Version 1.58

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $certificate (sort { $a->display_name() cmp $b->display_name() } $firefox->certificates()) {
        if ($certificate->is_ca_cert()) {
            print 'PEM Encoded CA Certificate ' . "\n" . $firefox->certificate_as_pem($certificate) . "\n";
        }
        ...
    }

=head1 DESCRIPTION

This module handles the implementation of a x509 Certificate from Firefox

=head1 SUBROUTINES/METHODS

=head2 common_name

returns the common name from the certificate.  This can contain the domain name (or wildcard) attached to the certificate or a Certificate Authority name, such as 'VeriSign Class 3 Public Primary Certification Authority - G4'

=head2 db_key

returns a unique value for the certificate.  This looks like a Base64 encoded string approximately 316 bytes long when encoded.

=head2 display_name

returns the display name field, such as 'VeriSign Class 3 Public Primary Certification Authority - G4'

=head2 email_address

returns the emailAddress field if supplied, otherwise it will return undef.

=head2 is_any_cert

returns a boolean value to determine if the certificate is a certificate.  This can return false for old browsers that do not support this attribute (such as Firefox 31.1.0esr).

=head2 is_built_in_root

returns a boolean value to determine if the certificate is a built in root certificate.

=head2 is_ca_cert

returns a boolean value to determine if the certificate is a certificate authority certificate

=head2 is_email_cert

returns a boolean value to determine if the certificate is an email certificate.

=head2 is_server_cert

returns a boolean value to determine if the certificate is a server certificate.

=head2 is_unknown_cert

returns a boolean value to determine if the certificate type is unknown.

=head2 is_user_cert

returns a boolean value to determine if the certificate is a user certificate.

=head2 issuer_common_name

returns the L<issuer common name|https://datatracker.ietf.org/doc/html/rfc5280#section-5.1.2.3> from the certificate, such as 'VeriSign Class 3 Public Primary Certification Authority - G4'

=head2 issuer_name

returns the L<issuer name|https://datatracker.ietf.org/doc/html/rfc5280#section-5.1.2.3> from the certificate, such as 'CN=VeriSign Class 3 Public Primary Certification Authority - G4,OU="(c) 2007 VeriSign, Inc. - For authorized use only",OU=VeriSign Trust Network,O="VeriSign, Inc.",C=US'

=head2 issuer_organization

returns the L<issuer organisation|https://datatracker.ietf.org/doc/html/rfc5280#section-5.1.2.3> from the certificate, such as 'VeriSign, Inc.'

=head2 issuer_organization_unit

returns the L<issuer organization unit|https://datatracker.ietf.org/doc/html/rfc5280#section-5.1.2.3> from the certificate, such as 'VeriSign Trust Network'

=head2 key_usages

returns a string describing the intended usages of the certificate, such as 'Certificate Signer'

=head2 new

This method is intended for use exclusively by the L<Firefox::Marionette|Firefox::Marionette> module.  You should not need to call this method from your code.

=head2 nickname

returns the nickname field, such as 'Builtin Object Token:VeriSign Class 3 Public Primary Certification Authority - G4'

=head2 not_valid_after

returns the L<not valid after|https://datatracker.ietf.org/doc/html/rfc5280#section-4.1.2.5> time in seconds since the UNIX epoch.

=head2 not_valid_before

returns the L<not valid before|https://datatracker.ietf.org/doc/html/rfc5280#section-4.1.2.5> time in seconds since the UNIX epoch.

=head2 organization

returns the organization field, such as 'VeriSign, Inc.'

=head2 organizational_unit

returns the organization unit field, such as 'VeriSign Trust Network'

=head2 serial_number

returns the L<serial number|https://datatracker.ietf.org/doc/html/rfc5280#section-4.1.2.2> of the certificate, such as '2F:80:FE:23:8C:0E:22:0F:48:67:12:28:91:87:AC:B3'

=head2 sha1_fingerprint

returns the sha1Fingerprint field, such as '22:D5:D8:DF:8F:02:31:D1:8D:F7:9D:B7:CF:8A:2D:64:C9:3F:6C:3A'

=head2 sha256_fingerprint

returns the sha256Fingerprint field, such as '69:DD:D7:EA:90:BB:57:C9:3E:13:5D:C8:5E:A6:FC:D5:48:0B:60:32:39:BD:C4:54:FC:75:8B:2A:26:CF:7F:79'

=head2 sha256_subject_public_key_info_digest

returns the base64 encoded sha256 digest of the L<subject public key info|https://datatracker.ietf.org/doc/html/rfc5280#section-4.1.2.7> field, such as 'UZJDjsNp1+4M5x9cbbdflB779y5YRBcV6Z6rBMLIrO4='

=head2 subject_name

returns the name from the L<subject|https://datatracker.ietf.org/doc/html/rfc5280#section-4.1.2.6> field, such as 'CN=VeriSign Class 3 Public Primary Certification Authority - G4,OU="(c) 2007 VeriSign, Inc. - For authorized use only",OU=VeriSign Trust Network,O="VeriSign, Inc.",C=US'

=head2 token_name

returns a string describing the type of certificate, such as 'Builtin Object Token'

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Certificate requires no configuration files or environment variables.

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
