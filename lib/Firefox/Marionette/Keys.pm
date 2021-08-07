package Firefox::Marionette::Keys;

use strict;
use warnings;
use Exporter();
*import = \&Exporter::import;
our @EXPORT_OK = qw(
  CANCEL
  HELP
  BACKSPACE
  TAB
  CLEAR
  ENTER
  SHIFT
  SHIFT_LEFT
  CONTROL
  CONTROL_LEFT
  ALT
  ALT_LEFT
  PAUSE
  ESCAPE
  SPACE
  PAGE_UP
  PAGE_DOWN
  END_KEY
  HOME
  ARROW_LEFT
  ARROW_UP
  ARROW_RIGHT
  ARROW_DOWN
  INSERT
  DELETE
  F1
  F2
  F3
  F4
  F5
  F6
  F7
  F8
  F9
  F10
  F11
  F12
  META
  META_LEFT
  ZENKAKU_HANKAKU
  SHIFT_RIGHT
  CONTROL_RIGHT
  ALT_RIGHT
  META_RIGHT
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK, );

our $VERSION = '1.12';

sub CANCEL          { return chr hex '0xE001' }
sub HELP            { return chr hex '0xE002' }
sub BACKSPACE       { return chr hex '0xE003' }
sub TAB             { return chr hex '0xE004' }
sub CLEAR           { return chr hex '0xE005' }
sub ENTER           { return chr hex '0xE006' }
sub SHIFT           { return chr hex '0xE008' }
sub SHIFT_LEFT      { return chr hex '0xE008' }
sub CONTROL         { return chr hex '0xE009' }
sub CONTROL_LEFT    { return chr hex '0xE009' }
sub ALT             { return chr hex '0xE00A' }
sub ALT_LEFT        { return chr hex '0xE00A' }
sub PAUSE           { return chr hex '0xE00B' }
sub ESCAPE          { return chr hex '0xE00C' }
sub SPACE           { return chr hex '0xE00D' }
sub PAGE_UP         { return chr hex '0xE00E' }
sub PAGE_DOWN       { return chr hex '0xE00F' }
sub END_KEY         { return chr hex '0xE010' }
sub HOME            { return chr hex '0xE011' }
sub ARROW_LEFT      { return chr hex '0xE012' }
sub ARROW_UP        { return chr hex '0xE013' }
sub ARROW_RIGHT     { return chr hex '0xE014' }
sub ARROW_DOWN      { return chr hex '0xE015' }
sub INSERT          { return chr hex '0xE016' }
sub DELETE          { return chr hex '0xE017' }
sub F1              { return chr hex '0xE031' }
sub F2              { return chr hex '0xE032' }
sub F3              { return chr hex '0xE033' }
sub F4              { return chr hex '0xE034' }
sub F5              { return chr hex '0xE035' }
sub F6              { return chr hex '0xE036' }
sub F7              { return chr hex '0xE037' }
sub F8              { return chr hex '0xE038' }
sub F9              { return chr hex '0xE039' }
sub F10             { return chr hex '0xE03A' }
sub F11             { return chr hex '0xE03B' }
sub F12             { return chr hex '0xE03C' }
sub META            { return chr hex '0xE03D' }
sub META_LEFT       { return chr hex '0xE03D' }
sub ZENKAKU_HANKAKU { return chr hex '0xE040' }
sub SHIFT_RIGHT     { return chr hex '0xE050' }
sub CONTROL_RIGHT   { return chr hex '0xE051' }
sub ALT_RIGHT       { return chr hex '0xE052' }
sub META_RIGHT      { return chr hex '0xE053' }

1;    # Magic true value required at end of module
__END__
=head1 NAME

Firefox::Marionette::Keys - Human readable special keys for the Marionette protocol

=head1 VERSION

Version 1.12

=head1 SYNOPSIS

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                                 $firefox->key_up('l'),
                                 $firefox->key_up(CONTROL())
                               )->content();

=head1 DESCRIPTION

This module handles the implementation of the Firefox Marionette human readable special keys

=head1 SUBROUTINES/METHODS

=head2 ALT

returns the Alt (the same as L<ALT_LEFT|Firefox::Marionette::Keys#ALT_LEFT>) codepoint, which is 0xE00A

=head2 ALT_LEFT

returns the Alt Left codepoint, which is 0xE00A

=head2 ALT_RIGHT

returns the Alt Right codepoint, which is 0xE052

=head2 ARROW_DOWN

returns the Arrow Down codepoint, which is 0xE015

=head2 ARROW_LEFT

returns the Arrow Left codepoint, which is 0xE012

=head2 ARROW_RIGHT

returns the Arrow Right codepoint, which is 0xE014

=head2 ARROW_UP

returns the Arrow Up codepoint, which is 0xE013

=head2 BACKSPACE

returns the Backspace codepoint, which is 0xE003

=head2 CANCEL

returns the Cancel codepoint, which is 0xE001

=head2 CLEAR

returns the Clear codepoint, which is 0xE005

=head2 CONTROL

returns the Control (the same as L<CONTROL_LEFT|Firefox::Marionette::Keys#CONTROL_LEFT>) codepoint, which is 0xE009

=head2 CONTROL_LEFT

returns the Control Left codepoint, which is 0xE009

=head2 CONTROL_RIGHT

returns the Control Right codepoint, which is 0xE051

=head2 DELETE

returns the Delete codepoint, which is 0xE017

=head2 END_KEY

returns the End codepoint, which is 0xE010

=head2 ENTER

returns the Enter codepoint, which is 0xE006

=head2 ESCAPE

returns the Escape codepoint, which is 0xE00C

=head2 F1

returns the F1 codepoint, which is 0xE031

=head2 F2

returns the F2 codepoint, which is 0xE032

=head2 F3

returns the F3 codepoint, which is 0xE033

=head2 F4

returns the F4 codepoint, which is 0xE034

=head2 F5

returns the F5 codepoint, which is 0xE035

=head2 F6

returns the F6 codepoint, which is 0xE036

=head2 F7

returns the F7 codepoint, which is 0xE037

=head2 F8

returns the F8 codepoint, which is 0xE038

=head2 F9

returns the F9 codepoint, which is 0xE039

=head2 F10

returns the F10 codepoint, which is 0xE03A

=head2 F11

returns the F11 codepoint, which is 0xE03B

=head2 F12

returns the F12 codepoint, which is 0xE03C

=head2 HELP

returns the Help codepoint, which is 0xE002

=head2 HOME

returns the Home codepoint, which is 0xE011

=head2 INSERT

returns the Insert codepoint, which is 0xE016

=head2 META

returns the Meta (the same as L<META_LEFT|Firefox::Marionette::Keys#META_LEFT>) codepoint, which is 0xE03D

=head2 META_LEFT

returns the Meta Left codepoint, which is 0xE03D

=head2 META_RIGHT

returns the Meta Right codepoint, which is 0xE053

=head2 PAGE_UP

returns the Page Up codepoint, which is 0xE00E

=head2 PAGE_DOWN

returns the Page Down codepoint, which is 0xE00F

=head2 PAUSE

returns the Pause codepoint, which is 0xE00B

=head2 SHIFT

returns the Shift (the same as L<SHIFT_LEFT|Firefox::Marionette::Keys#SHIFT_LEFT>) codepoint, which is 0xE008

=head2 SHIFT_LEFT

returns the Shift Left codepoint, which is 0xE008

=head2 SHIFT_RIGHT

returns the Shift Right codepoint, which is 0xE050

=head2 SPACE

returns the Space codepoint, which is 0xE00D

=head2 TAB

returns the Tab codepoint, which is 0xE004

=head2 ZENKAKU_HANKAKU

returns the Zenkaku (full-width) - Hankaku (half-width) codepoint, which is 0xE040

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Keys requires no configuration files or environment variables.

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
