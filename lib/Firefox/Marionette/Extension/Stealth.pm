package Firefox::Marionette::Extension::Stealth;

use File::HomeDir();
use File::Spec();
use Archive::Zip();
use English qw( -no_match_vars );
use strict;
use warnings;

our $VERSION = '1.59';

sub _BUFFER_SIZE  { return 65_536 }
sub _MSIE_VERSION { return 11 }

my $content_name = 'content.js';

my %_function_bodies = (
    'Navigator.bluetooth' =>
q[return { getAvailability: function () { return new Promise((resolve, reject) => resolve(false))} };],
    'Navigator.canShare'      => q[return true],
    'Navigator.clearAppBadge' =>
      q[return new Promise((resolve, reject) => resolve(undefined))],
    'Navigator.connection' =>
q[let downlink = (new Array(7.55, 1.6))[Math.floor(Math.random() * 2)]; let rtt = (new Array(50, 100))[Math.floor(Math.random() * 2)]; let obj = { onchange: null, effectiveType: decodeURIComponent(\\x27%274g%27\\x27), rtt: rtt, downlink: downlink, saveData: false }; return new NetworkInformation(obj)],
    'Navigator.deprecatedReplaceInURN' =>
q[throw TypeError(decodeURIComponent(\\x27Failed to execute %27deprecatedReplaceInURN%27 on %27Navigator%27: Passed URL must be a valid URN URL.\\x27))],
    'Navigator.deprecatedURNtoURL' =>
q[throw TypeError(decodeURIComponent(\\x27Failed to execute %27deprecatedURNtoURL%27 on %27Navigator%27: Passed URL must be a valid URN URL.\\x27))],
    'Navigator.deviceMemory' =>
      q[return (navigator.hardwareConcurrency < 4 ? 4 : 8)],
    'Navigator.getBattery' =>
q[return new Promise((resolve, reject) => resolve({ charging: true, chargingTime: 0, dischargingTime: Infinity, level: 1, onchargingchange: null }))],
    'Navigator.getGamePads' => q[return new Array( null, null, null, null )],
    'Navigator.getInstalledRelatedApps' =>
      q[return new Promise((resolve,reject) => resolve([]))],
    'Navigator.getUserMedia' => q[return getUserMedia],
    'Navigator.gpu'          => q[return { wgslLanguageFeatures: { size: 0 } }],
    'Navigator.hid'          =>
q[return { getDevices: function() { return new Promise((resolve,reject) => resolve([])) }, requestDevices: function() { return new Promise((resolve, reject) => resolve([])) } }],
    'Navigator.ink'      => q[return {}],
    'Navigator.keyboard' =>
q[return { getLayoutMap: function() { }, lock: function() { }, unlock: function() { } }],
    'Navigator.locks' =>
      q[return { query: function() { }, request: function() { } }],
    'Navigator.login' =>
      q[return { setStatus: function() { return undefined } }],
    'Navigator.webkitGetUserMedia' => q[return getUserMedia],
    'Navigator.xr' => q[return new XRSystem({ondevicechange: null})],
);

sub new {
    my ( $class, %agent_parameters ) = @_;
    my $zip = Archive::Zip->new();
    my $manifest =
      $zip->addString( $class->_manifest_contents(), 'manifest.json' );
    $manifest->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
    my $content = $zip->addString( $class->_content_contents(%agent_parameters),
        $content_name );
    $content->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );
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
    my ( $class, %agent_parameters ) = @_;
    my $user_agent_contents = $class->user_agent_contents(%agent_parameters);
    $user_agent_contents =~ s/\s+/ /smxg;
    $user_agent_contents =~ s/\\n/\\\\n/smxg;
    return <<"_JS_";
{
  let script = document.createElement('script');
  let text = document.createTextNode('$user_agent_contents');
  script.appendChild(text);
  (document.head || document.documentElement).appendChild(script);
  script.remove();
}
_JS_
}

my $_function_definition_count = 1;

sub _get_browser_type_and_version {
    my ( $class, $user_agent_string ) = @_;
    my ( $browser_type, $browser_version );
    if ( $user_agent_string =~ /Chrome\/(\d+)/smx ) {
        ( $browser_type, $browser_version ) = ( 'chrome', $1 );
        if ( $user_agent_string =~ /Edg(?:[eA]|iOS)?\/(\d+)/smx ) {
            ( $browser_type, $browser_version ) = ( 'edge', $1 );
        }
        elsif ( $user_agent_string =~ /(?:Opera|Presto|OPR)\/(\d+)/smx ) {
            ( $browser_type, $browser_version ) = ( 'opera', $1 );
        }
    }
    elsif (
        $user_agent_string =~ /Version\/(\d+)(?:[.]\d+)?[ ].*Safari\/\d+/smx )
    {
        ( $browser_type, $browser_version ) = ( 'safari', $1 );
    }
    elsif ( $user_agent_string =~ /Trident/smx ) {
        ( $browser_type, $browser_version ) = ( 'ie', _MSIE_VERSION() );
    }
    my $general_token_re   = qr/Mozilla\/5[.]0[ ]/smx;
    my $platform_etc_re    = qr/[(][^)]+[)][ ]/smx;
    my $gecko_trail_re     = qr/Gecko\/20100101[ ]/smx;
    my $firefox_version_re = qr/Firefox\/(\d+)[.]0/smx;
    if ( $user_agent_string =~
/^$general_token_re$platform_etc_re$gecko_trail_re$firefox_version_re$/smx
      )
    {
        ( $browser_type, $browser_version ) = ( 'firefox', $1 );
    }
    return ( $browser_type, $browser_version );
}

sub user_agent_contents {
    my ( $class, %parameters ) = @_;
    my ( $to_browser_type, $to_browser_version );
    if ( defined $parameters{to} ) {
        ( $to_browser_type, $to_browser_version ) =
          $class->_get_browser_type_and_version( $parameters{to} );
    }
    $_function_definition_count = 1;
    my ( $definition_name, $function_definition ) =
      $class->_get_js_function_definition( $to_browser_type, 'webdriver',
        'return false' );
    my $native_code_body = $class->_native_code_body($to_browser_type);
    my $contents         = <<"_JS_";
{
  if (("console" in window) && ("log" in window.console)) {
    console.log("Loading Firefox::Marionette::Extension::Stealth");
  }
  let navProto = Object.getPrototypeOf(window.navigator);
  let winProto = Object.getPrototypeOf(window);
  $function_definition
  Object.defineProperty(navProto, "webdriver", {get: $definition_name, enumerable: false, configurable: true});
  console.clear = function() { console.log("$class blocked an attempt at clearing the console...") };
  console.clear.toString = function clear_def() { return "function clear() $native_code_body" };
  let getUserMedia = navProto.mozGetUserMedia;
_JS_
    my ( $from_browser_type, $from_browser_version );
    if ( defined $to_browser_type ) {
        ( $from_browser_type, $from_browser_version ) =
          $class->_get_browser_type_and_version( $parameters{from} );
        if (   ( defined $from_browser_type )
            && ( $from_browser_type ne $to_browser_type ) )
        {
            $contents .= <<"_JS_";
  window.eval.toString = function eval_def() { return "function eval() $native_code_body" };
  Function.prototype.bind.toString = function bind_def() { return "function bind() $native_code_body" };
_JS_
        }
        if (   ( $to_browser_type eq 'chrome' )
            || ( $to_browser_type eq 'edge' )
            || ( $to_browser_type eq 'opera' ) )
        {
            $contents .= $class->_check_and_add_function(
                $to_browser_type,
                'Navigator.webkitPersistentStorage',
                {
                    function_body =>
q[return { queryUsageAndQuota: function() { return undefined }, requestQuota: function() { return undefined } }]
                },
                {}
            );
            $contents .= $class->_check_and_add_function(
                $to_browser_type,
                'Navigator.webkitTemporaryStorage',
                {
                    function_body =>
q[return { queryUsageAndQuota: function() { return undefined }, requestQuota: function() { return undefined } }]
                },
                {}
            );
            $contents .= $class->_check_and_add_function(
                $to_browser_type,
                'Window.webkitResolveLocalFileSystemURL',
                { function_body => q[return undefined] }, {}
            );
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Window.webkitMediaStream',
                { function_body => q[return undefined] }, {} );
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Window.webkitSpeechGrammar',
                { function_body => q[return undefined] }, {} );
            $contents .= <<'_JS_';
  delete navProto.oscpu;
  delete window.ApplePayError;
  delete window.CSSPrimitiveValue;
  delete window.Counter;
  delete navigator.getStorageUpdates;
  delete window.WebKitMediaKeys;
  let chrome = {
                  csi: function () { },
                  getVariableName: function () { },
                  loadTimes: function () { },
                  metricsPrivate: {
                                      MetricTypeType: {
                                                          HISTOGRAM_LINEAR: "histogram-linear",
                                                          HISTOGRAM_LOG:    "histogram-log"
                                                      },
                                      getFieldTrial: function () { },
                                      getHistogram: function () { },
                                      getVariationParams: function () { },
                                      recordBoolean: function () { },
                                      recordCount: function () { },
                                      recordEnumerationValue: function () { },
                                      recordLongTime: function () { },
                                      recordMediumCount: function () { },
                                      recordMediumTime: function () { },
                                      recordPercentage: function () { },
                                      recordSmallCount: function () { },
                                      recordSparseValue: function () { },
                                      recordSparseValueWithHashMetricName: function () { },
                                      recordSparseValueWithPersistentHash: function () { },
                                      recordTime: function () { },
                                      recordUserAction: function () { },
                                      recordValue: function () { }
                                  },
                  send: function () { },
                  timeTicks: { nowInMicroseconds: function () { } },
                  webstore: function () { },
                  app: function () { },
                  runtime: { connect: function() { }, sendMessage: function() { } }
               };
  Object.defineProperty(winProto, "chrome", {value: chrome, writable: true, enumerable: true, configurable: true});

  let canLoadAdAuctionFencedFrame = function() { return true };
 
  Object.defineProperty(navProto, "canLoadAdAuctionFencedFrame", {value: canLoadAdAuctionFencedFrame, writable: true, enumerable: true, configurable: true});

  let createAuctionNonce = function() { return crypto.randomUUID() };
  Object.defineProperty(navProto, "createAuctionNonce", {value: createAuctionNonce, writable: true, enumerable: true, configurable: true});

  Object.defineProperty(navProto, "deprecatedRunAdAuctionEnforcesKAnonymity", {value: false, writable: true, enumerable: true, configurable: true});
_JS_

            if ( $to_browser_type eq 'edge' ) {
            }
            elsif ( $to_browser_type eq 'opera' ) {
                my ( $scrap_name, $scrap_definition ) =
                  $class->_get_js_function_definition( $to_browser_type,
                    'scrap', 'return null' );
                $contents .= <<"_JS_";
  $scrap_definition
  Object.defineProperty(winProto, "g_opr", {value: {scrap: $scrap_name}, enumerable: true, configurable: true});
  Object.defineProperty(winProto, "opr", {value: {}, enumerable: true, configurable: true});
_JS_
            }
        }
        elsif ( $to_browser_type eq 'safari' ) {
            $contents .= <<'_JS_';
  delete navProto.oscpu;
  delete navigator.webkitPersistentStorage;
  delete navigator.webkitTemporaryStorage;
  delete window.webkitResolveLocalFileSystemURL;
  delete window.webkitMediaStream;
  delete window.webkitSpeechGrammar;
_JS_
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Window.ApplePayError',
                { function_body => q[return undefined] }, {} );
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Window.CSSPrimitiveValue',
                { function_body => q[return undefined] }, {} );
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Window.Counter', { function_body => q[return undefined] },
                {} );
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Navigator.getStorageUpdates',
                { function_body => q[return undefined] }, {} );
            $contents .=
              $class->_check_and_add_function( $to_browser_type,
                'Window.WebKitMediaKeys',
                { function_body => q[return undefined] }, {} );
        }
        elsif ( $to_browser_type eq 'ie' ) {
            $contents .= <<'_JS_';
  let docProto = Object.getPrototypeOf(window.document);
  delete navigator.webkitPersistentStorage;
  delete navigator.webkitTemporaryStorage;
  delete window.webkitResolveLocalFileSystemURL;
  delete window.webkitMediaStream;
  delete window.webkitSpeechGrammar;
  delete window.ApplePayError;
  delete window.CSSPrimitiveValue;
  delete window.Counter;
  delete navigator.getStorageUpdates;
  delete window.WebKitMediaKeys;
  Object.defineProperty(docProto, "documentMode", {value: true, writable: true, enumerable: true, configurable: true});
  Object.defineProperty(navProto, "msDoNotTrack", {value: "0", writable: true, configurable: true});
  Object.defineProperty(winProto, "msWriteProfilerMark", {value: {}, writable: true, configurable: true});
_JS_
        }
        if ( $to_browser_type eq 'firefox' ) {
            $contents .= <<'_JS_';
  delete navigator.webkitPersistentStorage;
  delete navigator.webkitTemporaryStorage;
  delete window.webkitResolveLocalFileSystemURL;
  delete window.webkitMediaStream;
  delete window.webkitSpeechGrammar;
  delete window.ApplePayError;
  delete window.CSSPrimitiveValue;
  delete window.Counter;
  delete navigator.getStorageUpdates;
  delete window.WebKitMediaKeys;
  if ("onmozfullscreenchange" in window) {
  } else {
    Object.defineProperty(window, "onmozfullscreenchange", {value: undefined, writable: true, configurable: true});
  }
  if ("mozInnerScreenX" in window) {
  } else {
    Object.defineProperty(window, "mozInnerScreenX", {value: 0, writable: true, configurable: true});
  }
  if ("CSSMozDocumentRule" in window) {
  } else {
    Object.defineProperty(window, "CSSMozDocumentRule", {value: undefined, writable: true, configurable: true});
  }
  if ("CanvasCaptureMediaStream" in window) {
  } else {
    Object.defineProperty(window, "CanvasCaptureMediaStream", {value: undefined, writable: true, configurable: true});
  }
_JS_
        }
        else {
            $contents .= <<'_JS_';
  delete navProto.buildID;
  delete window.InstallTrigger;
  delete navProto.mozGetUserMedia;
  delete window.onmozfullscreenchange;
  delete window.mozInnerScreenX;
  delete window.CSSMozDocumentRule;
  delete window.CanvasCaptureMediaStream;
_JS_
        }
        if ($from_browser_version) {
            $contents .= $class->_browser_compat_data(
                from_browser_type    => $from_browser_type,
                from_browser_version => $from_browser_version,
                to_browser_type      => $to_browser_type,
                to_browser_version   => $to_browser_version,
                filters              => $parameters{filters},
            );
        }
    }
    my %navigator_agent_mappings = (
        to          => 'userAgent',
        app_version => 'appVersion',
        platform    => 'platform',
        product     => 'product',
        product_sub => 'productSub',
        vendor      => 'vendor',
        vendor_sub  => 'vendorSub',
        oscpu       => 'oscpu',
    );
    foreach my $key ( sort { $a cmp $b } keys %navigator_agent_mappings ) {
        if ( defined $parameters{$key} ) {
            my $encoded = URI::Escape::uri_escape( $parameters{$key} );
            $contents .= $class->_check_and_add_function(
                $to_browser_type,
                'Navigator.' . $navigator_agent_mappings{$key},
                {
                    function_body =>
                      qq[return decodeURIComponent(\\x27$encoded\\x27)],
                    override => 1
                },
                {}
            );
        }
        elsif ( $parameters{to} ) {
            $contents .= <<"_JS_";
  delete navigator.$navigator_agent_mappings{$key};
_JS_
        }
    }
    $contents .= <<'_JS_';
  if (("console" in window) && ("log" in window.console)) {
    console.log("Loaded Firefox::Marionette::Extension::Stealth");
  }
}
_JS_
    return $contents;
}

sub _check_and_add_class {
    my ( $class, $property_name, $to_string_tag_allowed ) = @_;
    my $javascript_class = $property_name;
    my $win_proto_class  = $javascript_class;
    $win_proto_class =~ s/^Window[.]/winProto./smx;

    my $contents = <<"_JS_";
  if ("$javascript_class" in window) {
  } else {
    window.$javascript_class = class {
      constructor(obj) {
        for(let key of Object.keys(obj)) {
          Object.defineProperty(this, key, {value: obj[key], enumerable: true, configurable: true});
        }
      }
_JS_
    if ($to_string_tag_allowed) {
        $contents .= <<"_JS_";
      get [Symbol.toStringTag]() {
        return "$javascript_class";
      }
_JS_
    }
    $contents .= <<"_JS_";
    };
  }
_JS_
    return $contents;
}

sub _native_code_body {
    my ( $class, $to_browser_type ) = @_;
    my $native_code_body =
      q[{] . q[\\] . 'n\\x20\\x20\\x20\\x20[native code]' . q[\\] . q[n}];
    if ( ( defined $to_browser_type ) && ( $to_browser_type eq 'chrome' ) ) {
        $native_code_body = q[{ [native code] }];
    }
    return $native_code_body;
}

sub _get_js_function_definition {
    my ( $class, $to_browser_type, $name, $function_body ) = @_;
    $_function_definition_count += 1;
    my $native_code_body = $class->_native_code_body($to_browser_type);
    my $actual_name      = "fm_def_$_function_definition_count";
    return ( $actual_name, <<"_JS_");
let $actual_name = new Function("$function_body");
  $actual_name.toString = function fm_def() { return "function ${name}() $native_code_body" };
_JS_
}

sub _check_and_add_function {
    my ( $class, $to_browser_type, $property_name, $proposed_change_properties,
        $deleted_classes )
      = @_;
    my $javascript_class = $property_name;
    $javascript_class =~ s/[.][\-_@[:alnum:]]+$//smx;
    my $function_name = $property_name;
    $function_name =~ s/^.*[.]([\-_@[:alnum:]]+)$/$1/smx;
    my $parent_class = $javascript_class;
    if ( $javascript_class =~ /^(.*?)[.]/smx ) {
        $parent_class = ($1);
    }
    my $contents = q[];
    if ( !$deleted_classes->{$javascript_class} ) {
        my ( $definition_name, $function_definition ) =
          $class->_get_js_function_definition( $to_browser_type, $function_name,
            $proposed_change_properties->{function_body} );
        $contents .= <<"_JS_";
  $function_definition
_JS_
        if ( $proposed_change_properties->{override} ) {
            $contents .=
              <<"_JS_";    # So far, all overrides are Navigator overrides
  Object.defineProperty(window.$javascript_class, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
  Object.defineProperty(navProto, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
_JS_
        }
        elsif ( $javascript_class eq 'Window' ) {
            $contents .= <<"_JS_";
  if ("$function_name" in window) {
  } else {
    Object.defineProperty(window, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
  }
_JS_
        }
        else {
            $contents .= <<"_JS_";
  if (winProto.$parent_class && winProto.$javascript_class) {
    if ("$function_name" in winProto.$javascript_class) {
    } else {
      Object.defineProperty(winProto.$javascript_class.prototype, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
    }
  } else if (window.$parent_class && window.$javascript_class) {
    if (window.$javascript_class.prototype) {
      if ("$function_name" in window.$javascript_class.prototype) {
      } else {
        Object.defineProperty(window.$javascript_class.prototype, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
      }
    } else {
      if ("$function_name" in window.$javascript_class) {
      } else {
        Object.defineProperty(window.$javascript_class, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
      }
    }
_JS_
            if ( $javascript_class eq 'Navigator' ) {
                $contents .= <<"_JS_";
    Object.defineProperty(navProto, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
_JS_
            }
            elsif ( $javascript_class eq 'Document' ) {
                $contents .= <<"_JS_";
    Object.defineProperty(window.document, "$function_name", {get: $definition_name, enumerable: true, configurable: true});
_JS_
            }
            $contents .= <<"_JS_";
  }
_JS_
        }
    }
    return $contents;
}

sub _check_and_delete_class {
    my ( $class, $property_name ) = @_;
    my $parent_class = $property_name;
    if ( $property_name =~ /^(.*?)[.]/smx ) {
        ($parent_class) = ($1);
    }
    my $contents = <<"_JS_";
  if (winProto.$parent_class && winProto.$property_name) {
    delete winProto.$property_name;
  } else if (window.$parent_class && window.$property_name) {
    delete window.$property_name;
  }
_JS_
    if ( $property_name eq 'SubtleCrypto' ) {
        $contents .= <<'_JS_';
  if ("crypto" in window) {
    delete window["crypto"];
  }
_JS_
    }
    else {
        my $lc_property_name = lc $property_name;
        $contents .= <<"_JS_";
  if ("$lc_property_name" in window) {
    delete window["$lc_property_name"];
  }
_JS_
    }
    return $contents;
}

sub _check_and_delete_function {
    my ( $class, $property_name, $deleted_classes ) = @_;
    my $contents         = q[];
    my $javascript_class = $property_name;
    $javascript_class =~ s/[.][\-_@[:alpha:]]+$//smx;
    my $function_name = $property_name;
    $function_name =~ s/^.*[.]([\-_@[:alpha:]]+)$/$1/smx;
    my $parent_class = $javascript_class;
    if ( $javascript_class =~ /^(.*?)[.]/smx ) {
        $parent_class = ($1);
    }
    if ( !$deleted_classes->{$javascript_class} ) {
        $contents .= <<"_JS_";
  if (winProto.$parent_class && winProto.$javascript_class) {
    delete winProto.$javascript_class\["$function_name"\];
  } else if (window.$parent_class && window.$javascript_class) {
    if (window.$javascript_class.prototype) {
      delete window.$javascript_class.prototype\["$function_name"\];
    }
    delete window.$javascript_class\["$function_name"\];
  }
_JS_
    }
    if ( $javascript_class eq 'Navigator' ) {
        $contents .= <<"_JS_";
  if ("$function_name" in navProto) {
    delete navProto["$function_name"];
  } else if ("$function_name" in navigator) {
    delete navigator["$function_name"];
  }
_JS_
    }
    elsif ( $javascript_class eq 'Document' ) {
        $contents .= <<"_JS_";
  if (("document" in winProto) && ("$function_name" in winProto.document)) {
    delete winProto.document["$function_name"];
  } else if (("document" in window) && ("$function_name" in window.document)) {
    delete window.document["$function_name"];
  }
_JS_
    }
    elsif ( $javascript_class eq 'Window' ) {
        $contents .= <<"_JS_";
  if ("$function_name" in winProto) {
    delete winProto["$function_name"];
  } else if ("$function_name" in window) {
    delete window["$function_name"];
  }
_JS_
    }
    return $contents;
}

sub _read_bcd {
    my ($class) = @_;
    my %browser_properties;
    my $bcd_path = Firefox::Marionette::BCD_PATH();
    if (   ( defined $bcd_path )
        && ( my $bcd_handle = FileHandle->new( $bcd_path, Fcntl::O_RDONLY() ) )
      )
    {
        my $bcd_contents;
        my $result;
        while ( $result = $bcd_handle->read( my $buffer, _BUFFER_SIZE() ) ) {
            $bcd_contents .= $buffer;
        }
        close $bcd_handle
          or Firefox::Marionette::Exception->throw(
            "Failed to close '$bcd_path':$EXTENDED_OS_ERROR");
        %browser_properties = %{ JSON->new()->decode($bcd_contents) };
    }
    elsif ( $OS_ERROR == POSIX::ENOENT() ) {
        Carp::carp(
            q[BCD file is not available.  Please run 'build-bcd-for-firefox']);
    }
    else {
        Firefox::Marionette::Exception->throw(
            "Failed to open '$bcd_path' for reading:$EXTENDED_OS_ERROR");
    }
    return %browser_properties;
}

sub _available_in {
    my ( $class, %properties ) = @_;
    my $available;
    my $browser_type = $properties{browser_type};
    foreach my $proposed_change_properties ( @{ $properties{changes} } ) {
        if ( $proposed_change_properties->{add} ) {
            if ( $proposed_change_properties->{add} <=
                $properties{browser_version} )
            {
                if ( !$proposed_change_properties->{pref_name} ) {
                    if ( !defined $proposed_change_properties->{function_body} )
                    {
                        $proposed_change_properties->{function_body} =
                          $_function_bodies{ $properties{property_name} }
                          || 'return null';
                    }
                    $available = $proposed_change_properties;
                }
            }
        }
        elsif ( defined $proposed_change_properties->{rm} ) {
            if ( $proposed_change_properties->{rm} <=
                $properties{browser_version} )
            {
                $available = undef;
            }
        }
    }
    return $available;
}

sub _this_change_should_be_processed {
    my ( $class, $proposed_change, $property_name, $change_number, $filters ) =
      @_;
    if ( defined $filters ) {
        if ( $property_name !~ /$filters/smx ) {
            return 0;
        }
    }
    return 1;
}

sub _browser_compat_data {
    my ( $class, %parameters ) = @_;
    my %browser_properties = $class->_read_bcd();
    my $contents           = q[];
    my %deleted_classes;
    my $change_number = 0;
  VERSION:
    foreach my $property_name ( sort { $a cmp $b } keys %browser_properties ) {
        my $property_object = $browser_properties{$property_name};
        my $property_type   = $property_object->{type};
        my %from_properties = (
            browser_type    => $parameters{from_browser_type},
            browser_version => $parameters{from_browser_version},
            property_type   => $property_type,
            property_name   => $property_name,
            changes         => $browser_properties{$property_name}{browsers}
              { $parameters{from_browser_type} },
        );
        my %to_properties = (
            browser_type    => $parameters{to_browser_type},
            browser_version => $parameters{to_browser_version},
            property_type   => $property_type,
            property_name   => $property_name,
            changes         => $browser_properties{$property_name}{browsers}
              { $parameters{to_browser_type} },
        );
        my ( $delete_property, $add_property, $change_properties );
        if ( my $proposed_change_properties =
            $class->_available_in(%from_properties) )
        {
            if ( !$class->_available_in(%to_properties) ) {
                $delete_property = 1;
            }
        }
        else {
            if ( my $proposed_change_properties =
                $class->_available_in(%to_properties) )
            {
                $add_property      = 1;
                $change_properties = $proposed_change_properties;
            }
        }
        my $to_string_tag_allowed = 0;
        if (
            defined $browser_properties{'Symbol.toStringTag'}{browsers}
            { $parameters{to_browser_type} }[0]{add} )
        {
            if ( $browser_properties{'Symbol.toStringTag'}{browsers}
                { $parameters{to_browser_type} }[0]{add} <
                $parameters{to_browser_version} )
            {
                $to_string_tag_allowed = 1;
            }
        }
        my $change_details = {
            to_browser_type            => $parameters{to_browser_type},
            delete_property            => $delete_property,
            add_property               => $add_property,
            change_number              => $change_number,
            property_name              => $property_name,
            property_type              => $property_type,
            filters                    => $parameters{filters},
            proposed_change_properties => $change_properties,
            deleted_classes            => \%deleted_classes,
            to_string_tag_allowed      => $to_string_tag_allowed,
        };
        $contents .= $class->_process_change($change_details);
    }
    return $contents;
}

sub _process_change {
    my ( $class, $change_details ) = @_;
    my $contents = q[];
    if ( $change_details->{delete_property} ) {
        if ( $change_details->{property_type} eq 'class' ) {
            my $proposed_change = $class->_check_and_delete_class(
                $change_details->{property_name} );
            if (
                $class->_this_change_should_be_processed(
                    $proposed_change,
                    $change_details->{property_name},
                    $change_details->{change_number},
                    $change_details->{filters},
                )
              )
            {
                $contents .= $proposed_change;
                $change_details->{deleted_classes}
                  ->{ $change_details->{property_name} } = 1;
            }
        }
        else {
            if (
                my $proposed_change = $class->_check_and_delete_function(
                    $change_details->{property_name},
                    $change_details->{deleted_classes}
                )
              )
            {
                if (
                    $class->_this_change_should_be_processed(
                        $proposed_change,
                        $change_details->{property_name},
                        $change_details->{change_number},
                        $change_details->{filters},
                    )
                  )
                {
                    $contents .= $proposed_change;
                }
            }
        }
    }
    elsif ( $change_details->{add_property} ) {
        if ( $change_details->{property_type} eq 'class' ) {
            my $proposed_change = $class->_check_and_add_class(
                $change_details->{property_name},
                $change_details->{to_string_tag_allowed}
            );
            if (
                $class->_this_change_should_be_processed(
                    $proposed_change,
                    $change_details->{property_name},
                    $change_details->{change_number},
                    $change_details->{filters},
                )
              )
            {
                $contents .= $proposed_change;
            }
        }
        else {
            if (
                my $proposed_change = $class->_check_and_add_function(
                    $change_details->{to_browser_type},
                    $change_details->{property_name},
                    $change_details->{proposed_change_properties},
                    $change_details->{deleted_classes}
                )
              )
            {
                if (
                    $class->_this_change_should_be_processed(
                        $proposed_change,
                        $change_details->{property_name},
                        $change_details->{change_number},
                        $change_details->{filters},
                    )
                  )
                {
                    $contents .= $proposed_change;
                }
            }
        }
    }
    return $contents;
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Firefox::Marionette::Extension::Stealth - Contains the Stealth Extension

=head1 VERSION

Version 1.59

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

=head2 user_agent_contents

Returns the javascript used to setup a different (or the original) user agent as a string.

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
