package Firefox::Marionette::Extension::Stealth;

use Archive::Zip();
use strict;
use warnings;

our $VERSION = '1.52';

my $inject_name  = 'inject.js';
my $content_name = 'content.js';

sub new {
    my ($class) = @_;
    my $zip = Archive::Zip->new();
    my $manifest =
      $zip->addString( $class->_manifest_contents(), 'manifest.json' );
    $manifest->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
    my $content = $zip->addString( $class->_content_contents(), $content_name );
    $content->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
    my $inject = $zip->addString( $class->_inject_contents(), $inject_name );
    $inject->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
    return $zip;
}

sub _manifest_contents {
    my ($class) = @_;
    return <<"_JS_";
{
  "description": "Firefox::Marionette Stealth extension",
  "manifest_version": 2,
  "name": "Firefox Marionette Stealth extension",
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
    my ($class) = @_;
    return <<"_JS_";
{
  let script = document.createElement('script');
  script.src = chrome.runtime.getURL('$inject_name');
  script.onload = function() { this.remove(); };
  (document.head || document.documentElement).appendChild(script);
}
_JS_
}

sub _inject_contents {
    my ($class) = @_;
    return <<'_JS_';
{
  let navProto = Object.getPrototypeOf(window.navigator);
  let winProto = Object.getPrototypeOf(window);
  Object.defineProperty(navProto, 'webdriver', {value: false, writable: false, enumerable: false});
  let bluetooth = {
                    getAvailability: function () { return new Promise((resolve, reject) => resolve(false))},
               };
  let chrome = {
                  webstore: function () { },
                  app: function () { },
                  csi: function () { },
                  loadTimes: function () { },
                  runtime: { connect: function() { }, sendMessage: function() { } }
               };
  let canLoadAdAuctionFencedFrame = function() { return true };
  let canShare = function() { return true };
  let getUserMedia = window.navigator.mozGetUserMedia;
  let clearAppBadge = function () { return new Promise((resolve, reject) => resolve(undefined))};
  let clearOriginJoinedAdInterestGroup = function (url) { return new Promise((resolve, reject) => { if (new RegExp(/^https:/).exec(url)) { throw DOMException("Permission to leave interest groups denied.") } else { throw new TypeError("Failed to execute 'clearOriginJoinedAdInterestGroup' on 'Navigator': owner '" + url + "' must be a valid https origin") }})};
  delete window.navigator.mozGetUserMedia;
  let getBattery = function () { return new Promise((resolve, reject) => resolve({ charging: true, chargingTime: 0, dischargingTime: Infinity, level: 1, onchargingchange: null }))};
  let downlink = (new Array(7.55, 1.6))[Math.floor(Math.random() * 2)];
  let rtt = (new Array(0, 50, 100))[Math.floor(Math.random() * 3)];
  let connection = { effectiveType: '4g', rtt: rtt, downlink: downlink, saveData: false };
  let createAuctionNonce = function() { return crypto.randomUUID() };
  let deprecatedReplaceInURN = function() { throw TypeError("Failed to execute 'deprecatedReplaceInURN' on 'Navigator': Passed URL must be a valid URN URL.") };
  let deprecatedURNtoURL = function() { throw TypeError("Failed to execute 'deprecatedURNtoURL' on 'Navigator': Passed URL must be a valid URN URL.") };
  let getGamePads = function() { return new Array( null, null, null, null ) };
  let getInstalledRelatedApps = function() { return new Promise((resolve,reject) => resolve([])) };
  let gpu = { wgslLanguageFeatures: { size: 0 } };
  let hid = { getDevices: function() { return new Promise((resolve,reject) => resolve([])) }, requestDevices: function() { return new Promise((resolve, reject) => resolve([])) } };
  let joinAdInterestGroup = function (group) { return new Promise((resolve, reject) => { throw new TypeError("Failed to execute 'joinAdInterestGroup' on 'Navigator': The provided value is not of type 'AuctionAdInterestGroup'.")})};
  let keyboard = { getLayoutMap: function() { }, lock: function() { }, unlock: function() { } };
  let leaveAdInterestGroup = function () { throw new TypeError("Failed to execute 'leaveAdInterestGroup' on 'Navigator': May only leaveAdInterestGroup from an https origin.")};
  let locks = { query: function() { }, request: function() { } };
  let login = { setStatus: function() { return undefined } };
  if (navigator.userAgent.match(/Chrome/)) {
    Object.defineProperty(navProto, 'vendor', {value: "Google Inc.", writable: false});
    Object.defineProperty(navProto, 'productSub', {value: "20030107", writable: false});
    Object.defineProperty(navProto, 'getUserMedia', {value: getUserMedia, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'webkitGetUserMedia', {value: getUserMedia, writable: false, enumerable: true});
    try {
      Object.defineProperty(navProto, 'bluetooth', {value: bluetooth, writable: false, enumerable: true});
      Object.defineProperty(navProto, 'bluetooth', {value: bluetooth, writable: false, enumerable: true});
    } catch(e) {
      console.log("Unable to redefine bluetooth:" + e);
    }
    Object.defineProperty(winProto, 'chrome', {value: chrome, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'canLoadAdAuctionFencedFrame', {value: canLoadAdAuctionFencedFrame, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'canShare', {value: canShare, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'clearAppBadge', {value: clearAppBadge, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'clearOriginJoinedAdInterestGroup', {value: clearOriginJoinedAdInterestGroup, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'connection', {value: connection, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'createAuctionNonce', {value: createAuctionNonce, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'deprecatedReplaceInURN', {value: deprecatedReplaceInURN, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'deprecatedRunAdAuctionEnforcesKAnonymity', {value: false, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'deprecatedURNtoURL', {value: deprecatedURNtoURL, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'deviceMemory', {value: (navigator.hardwareConcurrency < 4 ? 4 : 8), writable: false, enumerable: true});
    Object.defineProperty(navProto, 'getBattery', {value: getBattery, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'getGamePads', {value: getGamePads, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'getInstalledRelatedApps', {value: getInstalledRelatedApps, writable: false, enumerable: true});
    if (!window.navigator.gpu) {
      Object.defineProperty(navProto, 'gpu', {value: gpu, writable: false, enumerable: true});
    }
    Object.defineProperty(navProto, 'hid', {value: hid, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'ink', {value: {}, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'joinAdInterestGroup', {value: joinAdInterestGroup, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'keyboard', {value: keyboard, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'leaveAdInterestGroup', {value: leaveAdInterestGroup, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'locks', {value: locks, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'login', {value: login, writable: false, enumerable: true});
    delete navProto.buildID;
    delete navProto.oscpu;
  } else if (navigator.userAgent.match(/Safari/)) {
    Object.defineProperty(navProto, 'vendor', {value: "Apple Computer, Inc.", writable: false});
    Object.defineProperty(navProto, 'productSub', {value: "20030107", writable: false});
    Object.defineProperty(navProto, 'getUserMedia', {value: getUserMedia, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'webkitGetUserMedia', {value: getUserMedia, writable: false, enumerable: true});
    /* no bluetooth for Safari - https://developer.mozilla.org/en-US/docs/Web/API/Bluetooth#browser_compatibility */
    Object.defineProperty(winProto, 'chrome', {value: chrome, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'canLoadAdAuctionFencedFrame', {value: canLoadAdAuctionFencedFrame, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'canShare', {value: canShare, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'clearAppBadge', {value: clearAppBadge, writable: false, enumerable: true});
    Object.defineProperty(navProto, 'clearOriginJoinedAdInterestGroup', {value: clearOriginJoinedAdInterestGroup, writable: false, enumerable: true});
    /* no connection for Safari - https://developer.mozilla.org/en-US/docs/Web/API/Navigator/connection#browser_compatibility */
    /* no deviceMemory for Safari - https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory#browser_compatibility */
    /* no getBattery for Safari - https://developer.mozilla.org/en-US/docs/Web/API/Navigator/getBattery#browser_compatibility */
    delete navProto.buildID;
    delete navProto.oscpu;
  } else {
    Object.defineProperty(navProto, 'vendor', {value: "", writable: false});
    Object.defineProperty(navProto, 'productSub', {value: "20100101", writable: false});
  }
}
_JS_
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Extension::Stealth - Contains the Stealth Extension

=head1 VERSION

Version 1.52

=head1 SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new(stealth => 1);
    $firefox->go("https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette");

=head1 DESCRIPTION

This module contains the Stealth extension.  This module should not be used directly.  It is required when the 'stealth' parameter is supplied to the L<new|Firefox::Marionette#new> method in L<Firefox::Marionette|Firefox::Marionette>.

=head1 SUBROUTINES/METHODS

=head2 new
 
Returns a L<Archive::Zip|Archive::Zip> of the Stealth extension.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Firefox::Marionette::Extension::Stealth requires no configuration files or environment variables.

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
