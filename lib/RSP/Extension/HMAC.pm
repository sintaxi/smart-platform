package RSP::Extension::HMAC;

use strict;
use warnings;

use Digest::HMAC_SHA1 qw( hmac_sha1 hmac_sha1_hex );
use Scalar::Util qw( blessed );

use base 'RSP::Extension';

sub extension_name {
  return "system.digest.hmac";
}

sub provides {
  return {
	  'digest' => {
		       'hmac' => {
			   'sha1' => {
				      'base64' => sub {
					my ($data, $key) = @_;
					my $dig = Digest::HMAC_SHA1->new( $key );
					if ( blessed( $data ) ) {
					  $dig->add( $data->as_string );
					} else {
					  $dig->add( $data );
					}
					return $dig->b64digest;
				      },
				      'hex' => sub {
					my ($data, $key) = @_;
					if ( blessed( $data ) ) {
					  return hmac_sha1_hex( $data->as_string, $key );
					}
					return hmac_sha1_hex( $data, $key );
				      }
				     }
				 }
		      }
	 }
}

1;

