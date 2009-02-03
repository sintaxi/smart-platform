package RSP::Extension::MD5;

use strict;
use warnings;

use Scalar::Util qw( blessed );
use Digest::MD5 qw( md5_hex md5_base64 );

use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    digest => {

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
