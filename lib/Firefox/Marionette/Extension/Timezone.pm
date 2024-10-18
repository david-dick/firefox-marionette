package Firefox::Marionette::Extension::Timezone;

use File::HomeDir();
use File::Spec();
use Archive::Zip();
use English qw( -no_match_vars );
use strict;
use warnings;

our $VERSION = '1.61';

my $content_name = 'content.js';

sub new {
    my ( $class, %timezone_parameters ) = @_;
    my $zip = Archive::Zip->new();
    my $manifest =
      $zip->addString( $class->_manifest_contents(), 'manifest.json' );
    $manifest->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
    my $content =
      $zip->addString( $class->_content_contents(%timezone_parameters),
        $content_name );
    $content->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
    return $zip;
}

sub _manifest_contents {
    my ($class) = @_;
    return <<"_JS_";
{
  "description": "Firefox::Marionette Timezone extension",
  "manifest_version": 2,
  "name": "Firefox Marionette Timezone extension",
  "version": "1.1",
  "permissions": [
    "activeTab"
  ],
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["$content_name"],
      "match_about_blank": true,
      "run_at": "document_start",
      "all_frames": true
    }
  ]
}
_JS_
}

sub _content_contents {
    my ( $class, %timezone_parameters ) = @_;
    my $timezone_contents = $class->timezone_contents(%timezone_parameters);
    $timezone_contents =~ s/\s+/ /smxg;
    $timezone_contents =~ s/\\n/\\\\n/smxg;
    return <<"_JS_";
{
  let script = document.createElement('script');
  let text = document.createTextNode('$timezone_contents');
  script.appendChild(text);
  (document.head || document.documentElement).appendChild(script);
  script.remove();
}
_JS_
}

sub timezone_contents {
    my ( $class, %parameters ) = @_;
    my $encoded_timezone = URI::Escape::uri_escape( $parameters{timezone} );
    my $encoded_locale   = URI::Escape::uri_escape('en-US');
    my $contents         = <<"_JS_";
{
  if (("console" in window) && ("log" in window.console)) {
    console.log("Loading Firefox::Marionette::Extension::Timezone");
  }
  let tz = decodeURIComponent("$encoded_timezone");
  let locale = decodeURIComponent("$encoded_locale");
  let setTimezone = function(win) { 
    win.Date.prototype.toString = function() { return
                        win.Intl.DateTimeFormat(locale, { weekday: "short", timeZone: tz }).format(this.valueOf()) + " " +
                        win.Intl.DateTimeFormat(locale, { month: "short", timeZone: tz }).format(this.valueOf()) + " " +
                        win.Intl.DateTimeFormat(locale, { day: "2-digit", timeZone: tz }).format(this.valueOf()) + " " +
                        win.Intl.DateTimeFormat(locale, { year: "numeric", timeZone: tz }).format(this.valueOf()) + " " +
                        win.Intl.DateTimeFormat(locale, { hour: "2-digit", hourCycle: "h24", timeZone: tz }).format(this.valueOf()) + ":" +
                        win.Intl.DateTimeFormat(locale, { minute: "2-digit", timeZone: tz }).format(this.valueOf()) + ":" +
                        win.Intl.DateTimeFormat(locale, { second: "2-digit", timeZone: tz }).format(this.valueOf()) + " " +
                        win.Intl.DateTimeFormat(locale, { timeZoneName: "longOffset", timeZone: tz }).format(this.valueOf()).replace(/:/,"").replace(/^[0-9]+.[0-9]+.[0-9]+,?[ ]/, "") + " (" +
                        win.Intl.DateTimeFormat(locale, { timeZoneName: "long", timeZone: tz }).format(this.valueOf()).replace(/^[0-9]+.[0-9]+.[0-9]+,?[ ]/, "") + ")"
    };

    /* https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/toLocaleString#options */

    win.Date.prototype.toLocaleString = function() { return win.Intl.DateTimeFormat(locale, { year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: tz }).format(this.valueOf()) };

    /* https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat/DateTimeFormat#date-time_component_options */

    win.Date.prototype.getDate = function() { return win.Intl.DateTimeFormat(locale, { day: "numeric", timeZone: tz }).format(this.valueOf()) };
    win.Date.prototype.getDay = function() { switch (win.Intl.DateTimeFormat("en-US", { weekday: "short", timeZone: tz }).format(this.valueOf())) { case "Sun": return 0; case "Mon": return 1; case "Tue": return 2; case "Wed": return 3; case "Thu": return 4; case "Fri": return 5; case "Sat": return 6 } };
    win.Date.prototype.getMonth = function() { return parseInt(win.Intl.DateTimeFormat(locale, { month: "numeric", timeZone: tz }).format(this.valueOf()), 10) - 1 };
    win.Date.prototype.getFullYear = function() { return win.Intl.DateTimeFormat(locale, { year: "numeric", timeZone: tz }).format(this.valueOf()) };
    win.Date.prototype.getHours = function() { return parseInt(win.Intl.DateTimeFormat(locale, { hour: "numeric", hourCycle: "h24", timeZone: tz }).format(this.valueOf()), 10) };
    win.Date.prototype.getMinutes = function() { return parseInt(win.Intl.DateTimeFormat(locale, { minute: "numeric", timeZone: tz }).format(this.valueOf()), 10) };

    let idtc = win.Intl.Collator;
    win.Intl.Collator = function() { if (!arguments[0]) { arguments[0] = [ locale ]  } return new idtc(arguments[0]) };
    let idtf = win.Intl.DateTimeFormat;
    win.Intl.DateTimeFormat = function() {
                        if (arguments[1]) {
                          if (!arguments[1]["timeZone"]) {
                            arguments[1]["timeZone"] = tz
                          }
                        } else {
                          arguments[1] = { "timeZone": tz }
                        }
                        if (!arguments[0]) {
                          arguments[0] = locale;
                        }
                        return idtf(arguments[0], arguments[1]);
    }; 
    let idtn = win.Intl.DisplayNames;
    win.Intl.DisplayNames = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new idtn(arguments[0], arguments[1]) };
    if ("DurationFormat" in win.Intl) {
      let idf = win.Intl.DurationFormat;
      win.Intl.DurationFormat = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return idf(arguments[0], arguments[1]) };
    }
    let ilf = win.Intl.ListFormat;
    win.Intl.ListFormat = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new ilf(arguments[0], arguments[1]) };
    let idtl = win.Intl.Locale;
    win.Intl.Locale = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new idtl(arguments[0]) };
    let inf = win.Intl.NumberFormat;
    win.Intl.NumberFormat = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new inf(arguments[0], arguments[1]) };
    let ipr = win.Intl.PluralRules;
    win.Intl.PluralRules = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new ipr(arguments[0]) };
    let irtf = win.Intl.RelativeTimeFormat;
    win.Intl.RelativeTimeFormat = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new irtf(arguments[0], arguments[1]) };
    let isg = win.Intl.Segmenter;
    win.Intl.Segmenter = function() { if (!arguments[0]) { arguments[0] = [ locale ] } return new isg(arguments[0], arguments[1]) };
  };
  setTimezone(window);

  /* https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver */

  new MutationObserver((mutationList, observer) => {
    for (let mutation of mutationList) {
      if (mutation.type === "childList") {
        for (let node of mutation.addedNodes) {
          if (node.nodeName === "IFRAME") {
            if (node.contentWindow !== null) {
              setTimezone(node.contentWindow);
            }
          }
        }
      }
    }
  }).observe((document.head || document.documentElement), { attributes: true, childList: true, subtree: true });

  if ("Worker" in window) {
    let tzw = window.Worker;
    window.Worker = function(url) {
      console.log("Worker told to start with " + url);
      return new tzw(url);
    };
  }
  if (("console" in window) && ("log" in window.console)) {
    console.log("Loaded Firefox::Marionette::Extension::Timezone");
  }
}
_JS_
    return $contents;
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Extension::Timezone - Contains the Timezone Extension

=head1 VERSION

Version 1.61

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new(stealth => 1);
    $firefox->go("https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette");

=head1 DESCRIPTION

This module contains the Timezone extension.  This module should not be used directly.  It is required when the 'stealth' parameter is supplied to the L<new|Firefox::Marionette#new> method in L<Firefox::Marionette|Firefox::Marionette>.

=head1 SUBROUTINES/METHODS

=head2 new
 
Returns a L<Archive::Zip|Archive::Zip> of the Timezone extension.

=head2 timezone_contents

Returns the javascript used to setup a different (or the original) user agent as a string.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Extension::Timezone requires no configuration files or environment variables.

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
