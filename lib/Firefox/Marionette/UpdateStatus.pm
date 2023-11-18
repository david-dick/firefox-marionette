package Firefox::Marionette::UpdateStatus;

use strict;
use warnings;
use URI();

our $VERSION = '1.49';

sub _NUMBER_OF_MILLISECONDS_IN_A_SECOND { return 1000 }

sub new {
    my ( $class, %parameters ) = @_;
    my $self = bless \%parameters, $class;
    return $self;
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

sub _resolve_to_boolean {
    my ( $self, $key ) = @_;
    if ( defined $self->{$key} ) {
        return $self->{$key} ? 1 : 0;
    }
    else {
        return;
    }
}

sub successful {
    my ($self) = @_;
    return ( ( defined $self->{update_status_code} )
          && ( $self->{update_status_code} eq 'PENDING_UPDATE' ) );
}

sub update_status_code {
    my ($self) = @_;
    return $self->{update_status_code};
}

sub type {
    my ($self) = @_;
    return $self->{type};
}

sub service_url {
    my ($self) = @_;
    return URI->new( $self->{service_url} );
}

sub details_url {
    my ($self) = @_;
    return URI->new( $self->{details_url} );
}

sub selected_patch {
    my ($self) = @_;
    return $self->{selected_patch};
}

sub build_id {
    my ($self) = @_;
    return $self->{build_id};
}

sub channel {
    my ($self) = @_;
    return $self->{channel};
}

sub unsupported {
    my ($self) = @_;
    return $self->_resolve_to_boolean('unsupported');
}

sub status_text {
    my ($self) = @_;
    return $self->{status_text};
}

sub elevation_failure {
    my ($self) = @_;
    return $self->_resolve_to_boolean('elevation_failure');
}

sub display_version {
    my ($self) = @_;
    return $self->{display_version};
}

sub update_state {
    my ($self) = @_;
    return $self->{update_state};
}

sub name {
    my ($self) = @_;
    return $self->{name};
}

sub app_version {
    my ($self) = @_;
    return $self->{app_version};
}

sub error_code {
    my ($self) = @_;
    return $self->{error_code};
}

sub install_date {
    my ($self) = @_;
    return $self->_convert_time_to_seconds( $self->{install_date} );
}

sub patch_count {
    my ($self) = @_;
    return $self->{patch_count};
}

sub number_of_updates {
    my ($self) = @_;
    return $self->{number_of_updates};
}

sub is_complete_update {
    my ($self) = @_;
    return $self->_resolve_to_boolean('is_complete_update');
}

sub prompt_wait_time {
    my ($self) = @_;
    return $self->{prompt_wait_time};
}

sub previous_app_version {
    my ($self) = @_;
    return $self->{previous_app_version};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::UpdateStatus - Represents the resulting status of an Firefox update

=head1 VERSION

Version 1.49

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    my $status = $firefox->update();
    while($status->successful()) {
        $status = $firefox->update();
    }
    say "Firefox has been upgraded to " . $status->display_version();

    

=head1 DESCRIPTION

This module handles the implementation of the status of a Firefox update using the Marionette protocol

=head1 SUBROUTINES/METHODS

=head2 new
 
accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * app_version - application version of this update.

=item * build_id -  L<build id|https://developer.mozilla.org/en-US/docs/Web/API/Navigator/buildID> of this update. Used to determine a particular build, down to the hour, minute and second of its creation. This allows the system to differentiate between several nightly builds with the same |version|.

=item * channel - L<channel|http://kb.mozillazine.org/App.update.channel> used to retrieve this update from the Update Service.

=item * details_url - L<URI|URI> offering details about the content of this update.  This page is intended to summarise the differences between this update and the previous, which also links to the release notes.

=item * display_version - string to display in the user interface for the version. If you want a real version number use app_version.

=item * elevation_failure - has an elevation failure has been encountered for this update.

=item * error_code - L<numeric error code|https://hg.mozilla.org/mozilla-central/file/tip/toolkit/mozapps/update/common/updatererrors.h> that conveys additional information about the state of a failed update. If the update is not in the "failed" state the value is zero.

=item * install_date - when the update was installed.

=item * is_complete_update - is the update a complete replacement of the user's existing installation or a patch representing the difference between the new version and the previous version.

=item * name - name of the update, which should look like "<Application Name> <Update Version>"

=item * number_of_updates - the number of updates available.

=item * patch_count - number of patches supplied by this update.

=item * previous_app_version - application version prior to the application being updated.

=item * prompt_wait_time - allows overriding the default amount of time in seconds before prompting the user to apply an update. If not specified, the value of L<app.update.promptWaitTime|http://kb.mozillazine.org/App.update.promptWaitTime> will be used.

=item * selected_patch - currently selected patch for this update.

=item * service_url - the Update Service that supplied this update.

=item * status_text - message associated with this update, if any.

=item * type - either 'minor', 'partial', which means a binary difference between two application versions or 'complete' which is a complete patch containing all of the replacement files to update to the new version

=item * unsupported - is the update no longer supported on this system.

=item * update_state - state of the selected patch;

=over 4

=item + downloading - the update is being downloaded.

=item + pending - the update is ready to be applied.

=item + pending-service - the update is ready to be applied with the service.

=item + pending-elevate - the update is ready to be applied but requires elevation.

=item + applying - the update is being applied.

=item + applied - the update is ready to be switched to.

=item + applied-os - the update is OS update and to be installed.

=item + applied-service - the update is ready to be switched to with the service.

=item + succeeded - the update was successfully applied.

=item + download-failed - the update failed to be downloaded.

=item + failed - the update failed to be applied.

=back

=item * update_status_code - a code describing the state of the patch.

=back

This method returns a new L<update status|Firefox::Marionette::UpdateStatus> object.
 
=head2 app_version

returns application version of this update.

=head2 build_id 

returns the L<build id|https://developer.mozilla.org/en-US/docs/Web/API/Navigator/buildID> of this update. Used to determine a particular build, down to the hour, minute and second of its creation. This allows the system to differentiate between several nightly builds with the same |version|.

=head2 channel

returns the L<channel|http://kb.mozillazine.org/App.update.channel> used to retrieve this update from the Update Service.

=head2 details_url

returns a L<URI|URI> offering details about the content of this update.  This page is intended to summarise the differences between this update and the previous, which also links to the release notes.

=head2 display_version

returns a string to display in the user interface for the version. If you want a real version number use app_version.

=head2 elevation_failure

returns a boolean to indicate if an elevation failure has been encountered for this update.

=head2 error_code

returns a L<numeric error code|https://hg.mozilla.org/mozilla-central/file/tip/toolkit/mozapps/update/common/updatererrors.h> that conveys additional information about the state of a failed update. If the update is not in the "failed" state the value is zero.

=head2 install_date

returns when the update was installed.

=head2 is_complete_update

returns a boolean to indicate if the update is a complete replacement of the user's existing installation or a patch representing the difference between the new version and the previous version.

=head2 name

returns name of the update, which should look like "<Application Name> <Update Version>"

=head2 number_of_updates

returns the number of updates available (seems to always be 1).

=head2 patch_count

returns the number of patches supplied by this update.

=head2 previous_app_version

returns application version prior to the application being updated.

=head2 prompt_wait_time

returns the amount of time in seconds before prompting the user to apply an update. If not specified, the value of L<app.update.promptWaitTime|http://kb.mozillazine.org/App.update.promptWaitTime> will be used.

=head2 selected_patch

returns the currently selected patch for this update.

=head2 service_url

returns a L<URI|URI> for the Update Service that supplied this update.

=head2 status_text

returns the message associated with this update, if any.

=head2 successful

returns a boolean to indicate if an update has been successfully applied.

=head2 type

returns either 'minor', 'partial', which means a binary difference between two application versions or 'complete' which is a complete patch containing all of the replacement files to update to the new version

=head2 unsupported 

returns a boolean to show if the update is supported on this system.

=head2 update_state

returns the state of the selected patch;

=over 4

=item + downloading - the update is being downloaded.

=item + pending - the update is ready to be applied.

=item + pending-service - the update is ready to be applied with the service.

=item + pending-elevate - the update is ready to be applied but requires elevation.

=item + applying - the update is being applied.

=item + applied - the update is ready to be switched to.

=item + applied-os - the update is OS update and to be installed.

=item + applied-service - the update is ready to be switched to with the service.

=item + succeeded - the update was successfully applied.

=item + download-failed - the update failed to be downloaded.

=item + failed - the update failed to be applied.

=back

The most usual state is "pending"

=head2 update_status_code

returns a code describing the state of the patch.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::UpdateStatus requires no configuration files or environment variables.

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
