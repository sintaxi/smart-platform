package RSP::Extension::Digest;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use Digest::MD5 qw( md5_hex md5_base64 );
use Digest::SHA1 qw( sha1_hex sha1_base64 );

use base 'RSP::Extension';

sub exception_name {
  return "system.digest";
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    digest => {

      sha1 => {
        'hex' => sub {
	  my $data = shift;
	  if ( blessed( $data ) ) {
	    return sha1_hex( $data->as_string );
	  }
	  return sha1_hex( $data );
	},
	'base64' => sub {
	  my $data = shift;
	  if ( blessed( $data ) ) {
	    return sha1_base64( $data->as_string );
	  }
	  return sha1_base64( $data );
	}
      },

      md5 => {
        'hex' => sub {
          my $data = shift;
	  if ( blessed( $data ) ) {
	    return md5_hex( $data->as_string );
	  }
          return md5_hex( $data );
        },
        'base64' => sub {
          my $data = shift;
	  if ( blessed( $data ) ) {
	    return md5_hex( $data->as_string );
	  }
          return md5_base64( $data );
        },
      }
    }
  }
}

1;
