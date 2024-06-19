#! /usr/bin/perl -w

use strict;
use Firefox::Marionette();
use Crypt::URandom();
use MIME::Base64();
use Test::More;

$SIG{INT} = sub { die "Caught an INT signal"; };
$SIG{TERM} = sub { die "Caught a TERM signal"; };

SKIP: {
	if (!$ENV{RELEASE_TESTING}) {
                plan skip_all => "Author tests not required for installation";
	}
	if ($^O eq 'MSWin32') {
		plan skip_all => "Cannot test in a $^O environment";
	}
	my $profile = Firefox::Marionette::Profile->new();
	my @extra_parameters;
	if ($ENV{FIREFOX_BINARY}) {
		push @extra_parameters, (binary => $ENV{FIREFOX_BINARY});
	}
	my $debug = $ENV{FIREFOX_DEBUG} || 0;
	my $visible = $ENV{FIREFOX_VISIBLE} || 0;
	my $loop_max = $ENV{FIREFOX_MAX_LOOP} || 1;
	my $firefox = Firefox::Marionette->new(
		@extra_parameters,
		debug => $debug,
		visible => $visible,
		profile => $profile,
                devtools => $debug && $visible,
			);
	ok($firefox, "Created a firefox object");
	my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
	ok($user_name, "User is $user_name");
	my $host_name = 'webauthn.io';
	my ($major_version, $minor_version, $patch_version) = split /[.]/,$firefox->browser_version();
	if ($major_version >= 118) {
		my $result;
		eval {
			$result = $firefox->go('https://' . $host_name);
		};
		ok($result, "Loading https://$host_name:$@");
		ok($firefox->find_id('input-email')->type($user_name), "Entering $user_name for username");
		ok($firefox->find_id('register-button')->click(), "Registering authentication for $host_name");;
		$firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
		ok($firefox->find_id('login-button')->click(), "Clicking login button for $host_name");
		ok($firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); }), "Successfully authenticated to $host_name");
		my $authenticator = $firefox->webauthn_authenticator();
		ok($authenticator, "Successfully retrieved WebAuthn Authenticator:" . $authenticator->id());
		my $sign_count_after_one_login;
		my $count = 0;
		foreach my $credential ($firefox->webauthn_credentials()) {
			ok($credential->id(), "Credential id is " . $credential->id());
			ok($credential->host() eq $host_name, "Hostname is $host_name:" . $credential->host());
			ok($credential->user(), "Username is " . $credential->user());
			$sign_count_after_one_login = $credential->sign_count();
			ok($credential->sign_count() >= 1, "Sign Count is >= 1:" . $credential->sign_count());
			$firefox->delete_webauthn_credential($credential);
			$firefox->add_webauthn_credential(
					id => $credential->id(), 
					host => $credential->host(),
					user => $credential->user(),
					private_key => $credential->private_key(),
					is_resident => $credential->is_resident(),
					sign_count => $credential->sign_count(),
							);
		}
		ok($firefox->go('about:blank'), "Loading about:blank");
		ok($firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_COOKIES()), "Deleting all cookies");
		ok($firefox->go('https://' . $host_name), "Loading https://$host_name");
		ok($firefox->find_id('input-email')->type($user_name), "Entering $user_name for username");
		ok($firefox->find_id('login-button')->click(), "Clicking login button for $host_name");
		ok($firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); }), "Successfully authenticated to $host_name");
		$count = 0;
		foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
			ok($credential->id(), "Credential id is " . $credential->id());
			ok($credential->host() eq $host_name, "Hostname is $host_name:" . $credential->host());
			ok($credential->user(), "Username is " . $credential->user());
			ok($credential->sign_count() == ($sign_count_after_one_login * 2), "Sign Count is == ($sign_count_after_one_login * 2):" . $credential->sign_count());
		}
		ok($firefox->delete_webauthn_all_credentials($authenticator), "Deleted all Webauthn credentials");
		$host_name = 'webauthn.bin.coffee';
		ok($firefox->go("https://$host_name"), "Loaded https://$host_name");
		ok($firefox->find_id('createButton')->click(), "Clicked 'Create Credential'");
		ok($firefox->find_id('getButton')->click(), "Clicked 'Get Assertion'");
		foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
			ok($credential->id(), "Credential id is " . $credential->id());
			ok($credential->host() eq $host_name, "Hostname is " . $credential->host());
			ok($credential->user(), "Username is " . $credential->user());
			ok($credential->sign_count(), "Sign Count is " . $credential->sign_count());
		}
		$authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::HYBRID(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2(), has_resident_key => 1 );
		ok($authenticator, "Successfully added CTAP2/Hybrid WebAuthn Authenticator:" . $authenticator->id());
		ok($authenticator->transport() eq 'hybrid', "Correct transport of 'hybrid' is returned:" . $authenticator->transport());
		ok($authenticator->protocol() eq 'ctap2', "Correct protocol of 'ctap2' is returned:" . $authenticator->protocol());
		ok($authenticator->has_resident_key() == 1, "Correct value for has_resident_key is returned:" . $authenticator->has_resident_key());
		$authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2_1(), has_resident_key => 0, is_user_verified => 1 );
		ok($authenticator, "Successfully added CTAP2_1/Internal WebAuthn Authenticator:" . $authenticator->id());
		ok($authenticator->transport() eq 'internal', "Correct transport of 'internal' is returned:" . $authenticator->transport());
		ok($authenticator->protocol() eq 'ctap2_1', "Correct protocol of 'ctap2_1' is returned:" . $authenticator->protocol());
		ok($authenticator->has_resident_key() == 0, "Correct value for has_resident_key is returned:" . $authenticator->has_resident_key());
		ok($authenticator->is_user_verified() == 1, "is_user_verified() is 1:" . $authenticator->is_user_verified());
		$authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::NFC(), has_user_verification => 0, is_user_consenting => 1 );
		ok($authenticator, "Successfully added NFC WebAuthn Authenticator:" . $authenticator->id());
		ok($authenticator->transport() eq 'nfc', "Correct transport of 'nfc' is returned:" . $authenticator->transport());
		ok($authenticator->has_user_verification() == 0, "has_user_verification == 0:" . $authenticator->has_user_verification());
		ok($authenticator->is_user_consenting() == 1, "is_user_consenting == 1:" . $authenticator->is_user_consenting());
		$authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::SMART_CARD(), has_user_verification => 1, is_user_consenting => 0 );
		ok($authenticator, "Successfully added Smart Card WebAuthn Authenticator:" . $authenticator->id());
		ok($authenticator->transport() eq 'smart-card', "Correct transport of 'smart-card' is returned:" . $authenticator->transport());
		ok($authenticator->has_user_verification() == 1, "has_user_verification == 1:" . $authenticator->has_user_verification());
		ok($authenticator->is_user_consenting() == 0, "is_user_consenting == 0:" . $authenticator->is_user_consenting());
		$authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::USB(), is_user_verified => 0 );
		ok($authenticator, "Successfully added USB WebAuthn Authenticator:" . $authenticator->id());
		ok($authenticator->transport() eq 'usb', "Correct transport of 'usb' is returned:" . $authenticator->transport());
		ok($authenticator->is_user_verified() == 0, "is_user_verified() is 0:" . $authenticator->is_user_verified());
		ok($firefox->webauthn_set_user_verified(undef, $authenticator), "verify webauthn user to default (true)");
		ok($firefox->webauthn_set_user_verified(0), "verify webauthn user to false");
		ok($firefox->webauthn_set_user_verified(1), "verify webauthn user to true");
		my $credential = Firefox::Marionette::WebAuthn::Credential->new( host => 'example.org', is_resident => 1 );
		ok($credential, "Webauthn credential created");
		ok(!$credential->id(), "Credential id does not exist yet");
		ok($credential->host(), "Hostname is " . $credential->host());
		ok($credential->is_resident() == 1, "is_resident is 1:" . $credential->is_resident());
		my $cred_id = 'rDFWHBYyRzQGhu92NBf6P6QOhGlsvjtxZB8b8GBWhwg';
		$host_name = 'example.net';
		eval {
			$credential = $firefox->add_webauthn_credential( authenticator => $authenticator, id => $cred_id, host => $host_name, is_resident => 0);
		};
		foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
			ok($credential->id() eq $cred_id, "Credential id is '$cred_id':" . $credential->id());
			ok($credential->host() eq $host_name, "Hostname is '$host_name':" . $credential->host());
			ok(!$credential->user(), "Username is empty");
			ok($credential->is_resident() == 0, "is_resident is 0:" . $credential->is_resident());
			ok($credential->sign_count() == 0, "Sign Count is 0:" . $credential->sign_count());
			$firefox->delete_webauthn_credential($credential, $authenticator);
		}
		eval {
			$credential = $firefox->add_webauthn_credential( private_key => { name => 'RSA-PSS', size => 1024 }, host => $host_name, user => $user_name);
			ok($credential->id(), "Credential id is " . $credential->id());
			ok($credential->host() eq $host_name, "Hostname is '$host_name':" . $credential->host());
			ok($credential->user() eq $user_name, "Username is '$user_name':" . $credential->user());
		};
		ok($firefox->delete_webauthn_authenticator($authenticator), "Deleted virtual authenticator");
		my $default_authenticator = $firefox->webauthn_authenticator();
		ok($default_authenticator, "Default virtual authenticator still exists");
		ok($firefox->delete_webauthn_authenticator(), "Deleted default virtual authenticator");
		ok(!$firefox->webauthn_authenticator(), "Default virtual authenticator no longer exists");
		$authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::BLE(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP1_U2F() );
		ok($authenticator, "Successfully added CTAP1_U2F/BLE WebAuthn Authenticator:" . $authenticator->id());
		ok($authenticator->transport() eq 'ble', "Correct transport of 'ble' is returned:" . $authenticator->transport());
		ok($authenticator->protocol() eq 'ctap1/u2f', "Correct protocol of 'ctap1/u2f' is returned:" . $authenticator->protocol());
		ok($firefox->delete_webauthn_authenticator($authenticator), "Deleted virtual authenticator");
		eval {
			$firefox->delete_webauthn_authenticator($default_authenticator);
		};
		chomp $@;
		ok($@, "Failed to delete non-existant authenticator:$@");
		$firefox = Firefox::Marionette->new(
			@extra_parameters,
			debug => $debug,
			visible => $visible,
			profile => $profile,
			devtools => $debug && $visible,
			webauthn => 0,
				);
		ok(!$firefox->webauthn_authenticator(), "Default virtual authenticator was not created");
		$firefox = Firefox::Marionette->new(
			@extra_parameters,
			debug => $debug,
			visible => $visible,
			profile => $profile,
			devtools => $debug && $visible,
			webauthn => 1,
				);
		ok($firefox->webauthn_authenticator(), "Default virtual authenticator was created");
	} else {
		diag("Webauthn not available for versions less than 118");
		eval {
			$firefox = Firefox::Marionette->new(
				@extra_parameters,
				debug => $debug,
				visible => $visible,
				profile => $profile,
				devtools => $debug && $visible,
				webauthn => 1,
					);
			1;
		};
		chomp $@;
		ok(1, "What happens when we force a webauthn authenticator to be added when it's not supported:$@");
	}
}

done_testing();
