package Firefox::Marionette::Login;

use strict;
use warnings;

our $VERSION = '1.32';

sub _NUMBER_OF_MILLISECONDS_IN_A_SECOND { return 1000 }

sub new {
    my ( $class, %parameters ) = @_;

    if ( !exists $parameters{realm} ) {
        $parameters{realm} = undef;
    }
    foreach my $key (qw(creation last_used password_changed)) {
        if ( defined $parameters{ $key . '_in_ms' } ) {
            delete $parameters{ $key . '_time' };
        }
        elsif ( defined $parameters{ $key . '_time' } ) {
            my $value = delete $parameters{ $key . '_time' };
            $parameters{ $key . '_in_ms' } =
              $value * _NUMBER_OF_MILLISECONDS_IN_A_SECOND();
        }
    }
    my $self = bless {%parameters}, $class;
    return $self;
}

sub TO_JSON {
    my ($self) = @_;
    my $json = {};
    foreach my $key ( sort { $a cmp $b } keys %{$self} ) {
        $json->{$key} = $self->{$key};
    }
    return $json;
}

sub _convert_time_to_seconds {
    my ( $self, $milliseconds ) = @_;
    if ( defined $milliseconds ) {
        my $seconds = $milliseconds / _NUMBER_OF_MILLISECONDS_IN_A_SECOND();
        return int $seconds;
    }
    else {
        return;
    }
}

sub host {
    my ($self) = @_;
    return $self->{host};
}

sub user {
    my ($self) = @_;
    return $self->{user};
}

sub user_field {
    my ($self) = @_;
    return $self->{user_field};
}

sub password {
    my ($self) = @_;
    return $self->{password};
}

sub password_field {
    my ($self) = @_;
    return $self->{password_field};
}

sub realm {
    my ($self) = @_;
    return $self->{realm};
}

sub origin {
    my ($self) = @_;
    return $self->{origin};
}

sub guid {
    my ($self) = @_;
    return $self->{guid};
}

sub times_used {
    my ($self) = @_;
    return $self->{times_used};
}

sub creation_time {
    my ($self) = @_;
    return $self->_convert_time_to_seconds( $self->creation_in_ms() );
}

sub creation_in_ms {
    my ($self) = @_;
    return $self->{creation_in_ms};
}

sub last_used_time {
    my ($self) = @_;
    return $self->_convert_time_to_seconds( $self->last_used_in_ms() );
}

sub last_used_in_ms {
    my ($self) = @_;
    return $self->{last_used_in_ms};
}

sub password_changed_time {
    my ($self) = @_;
    return $self->_convert_time_to_seconds( $self->password_changed_in_ms() );
}

sub password_changed_in_ms {
    my ($self) = @_;
    return $self->{password_changed_in_ms};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Login - Represents a login from the Firefox Password Manager

=head1 VERSION

Version 1.32

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $login ($firefox->logins()) {
        if ($login->user() eq 'me@example.org') {
            ...
        }
    }

=head1 DESCRIPTION

This module handles the implementation of a L<login|https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsILoginInfo> from the Firefox L<Password Manager|https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins>

=head1 SUBROUTINES/METHODS

=head2 creation_time

returns the time, in Unix Epoch seconds, when the login was first created.

=head2 creation_in_ms

returns the time, in Unix Epoch milliseconds, when the login was first created.  This is the same time as L<creation_in_ms|creation_in_ms> but divided by 1000 and turned back into an integer.

=head2 guid

returns the GUID to uniquely identify the login.

=head2 host

returns the scheme + hostname (for example "https://example.com") of the page containing the login form.

=head2 last_used_time

returns the time, in Unix Epoch seconds, when the login was last submitted in a form or used to begin an HTTP auth session.  This is the same time as L<last_used_in_ms|last_used_in_ms> but divided by 1000 and turned back into an integer.

=head2 last_used_in_ms

returns the time, in Unix Epoch milliseconds, when the login was last submitted in a form or used to begin an HTTP auth session.

=head2 origin

returns the scheme + hostname (for example "https://example.org") of the L<action|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action> attribute of the form that is being submitted.

=head2 new

accepts an optional hash as a parameter.  Allowed keys are below;

=over 4

=item * creation_in_ms - the time, in Unix Epoch milliseconds, when the login was first created.

=item * creation_time - the time, in Unix Epoch seconds, when the login was first created.  This value will be overridden by the more precise creation_in_ms parameter, if provided.

=item * guid - the GUID to uniquely identify the login. This can be any arbitrary string, but a format as created by L<nsIUUIDGenerator|https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIUUIDGenerator> is recommended. For example, "{d4e1a1f6-5ea0-40ee-bff5-da57982f21cf}".

=item * host - this is the scheme + hostname (for example "https://example.com") of the page containing the login form.

=item * last_used_in_ms returns the time, in Unix Epoch milliseconds, when the login was last submitted in a form or used to begin an HTTP auth session.

=item * last_used_time - the time, in Unix Epoch seconds, when the login was last submitted in a form or used to begin an HTTP auth session.  This value will be overridden by the more precise last_used_in_ms parameter, if provided.

=item * origin - this is the scheme + hostname (for example "https://example.org") of the L<action|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action> attribute of the form that is being submitted.  If the L<action|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action> attribute has an empty or relative URL, then this value should be the same as the host.  If this value is ignored, it will apply for forms with L<action|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action> of all values.

=item * password - the password for the login.

=item * password_changed_in_ms - the time, in Unix Epoch milliseconds, when the login's password was last modified.

=item * password_changed_time -  the time, in Unix Epoch seconds, when the login's password was last modified.  This value will be overridden by the more precise password_changed_in_ms parameter, if provided.

=item * password_field - the L<name|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input#htmlattrdefname> attribute for the password input in a form.  This is ignored for http auth logins.

=item * realm - the HTTP Realm for which the login was requested.  This is ignored for HTML Form logins.

=item * times_used - the number of times the login was submitted in a form or used to begin an HTTP auth session.

=item * user - the user name for the login.

=item * user_field - the L<name|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input#htmlattrdefname> attribute for the user input in a form.  This is ignored for http auth logins.

=back

This method returns a new C<Firefox::Marionette::Login> object.

=head2 password

returns the password for the login.

=head2 password_changed_time

returns the time, in Unix Epoch seconds, when the login's password was last modified.  This is the same time as L<password_changed_in_ms|password_changed_in_ms> but divided by 1000 and turned back into an integer.

=head2 password_changed_in_ms

returns the time, in Unix Epoch milliseconds, when the login's password was last modified.

=head2 password_field

returns the L<name|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input#htmlattrdefname> attribute for the password input in a form or undef for non-form logins.

=head2 realm

returns the HTTP Realm for which the login was requested. When an HTTP server sends a 401 result, the WWW-Authenticate header includes a realm to identify the "protection space." See RFC 2617. If the result did not include a realm, or it was blank, the hostname is used instead. For logins obtained from HTML forms, this field is null.

=head2 times_used

returns the number of times the login was submitted in a form or used to begin an HTTP auth session.

=head2 user

returns the user name for the login.

=head2 user_field

returns the L<name|https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input#htmlattrdefname> attribute for the user input in a form or undef for non-form logins.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Login requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

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
