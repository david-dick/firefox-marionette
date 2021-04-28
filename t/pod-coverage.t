#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok({ trustme => [
		 qr/^BY_(ID|NAME|CLASS|TAG|SELECTOR|LINK|PARTIAL|XPATH)$/,
		 qr/^(find_elements?|page_source|send_keys)$/,
		 qr/^(active_frame|switch_to_shadow_root)$/,
		 qr/^(xvfb)$/,
		 qr/^(TO_JSON)$/,
		 qr/^(list.*)$/,
		 qr/^(accept_dialog)$/,
		 qr/^(find_by_.*)$/,
			 ] });
