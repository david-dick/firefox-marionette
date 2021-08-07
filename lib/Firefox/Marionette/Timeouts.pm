package Firefox::Marionette::Timeouts;

use strict;
use warnings;

our $VERSION = '1.12';

sub new {
    my ( $class, %parameters ) = @_;
    my $element = bless {%parameters}, $class;
    return $element;
}

sub page_load {
    my ($self) = @_;
    return $self->{page_load};
}

sub script {
    my ($self) = @_;
    return $self->{script};
}

sub implicit {
    my ($self) = @_;
    return $self->{implicit};
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Timeouts - Represents the timeouts for page loading, searching, and scripts.

=head1 VERSION

Version 1.12

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $timeouts = $firefox->timeouts();
    say "Page Load Timeouts is " . $timeouts->page_load() . " ms";

=head1 DESCRIPTION

This module handles the implementation of the Firefox Marionette Timeouts

=head1 SUBROUTINES/METHODS

=head2 new
 
accepts a hash as a parameter.  Allowed keys are below;

=over 4

=item * page_load - the timeout used for L<go|Firefox::Marionette#go>, L<back|Firefox::Marionette#back>, L<forward|Firefox::Marionette#forward>, L<refresh|Firefox::Marionette#refresh> and L<click|Firefox::Marionette#click> methods in milliseconds

=item * script - the timeout used for L<script|Firefox::Marionette#script> and L<async_script|Firefox::Marionette#async_script> methods in milliseconds

=item * implicit - the timeout used for L<find|Firefox::Marionette#find> and L<list|Firefox::Marionette#list> methods in milliseconds

=back

This method returns a new L<timeout|Firefox::Marionette::Timeout> object.
 
=head2 page_load

returns the the timeout used for L<go|Firefox::Marionette#go>, L<back|Firefox::Marionette#back>, L<forward|Firefox::Marionette#forward>, L<refresh|Firefox::Marionette#refresh> and L<click|Firefox::Marionette#click> methods in milliseconds.

=head2 script

returns the the timeout used for L<script|Firefox::Marionette#script> and L<async_script|Firefox::Marionette#async_script> methods in milliseconds.

=head2 implicit

returns the timeout used for L<find|Firefox::Marionette#find> and L<list|Firefox::Marionette#list> methods in milliseconds

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Timeouts requires no configuration files or environment variables.

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
