package RSP::Extension::Digest;

use strict;
use warnings;

use Digest::MD5 qw( md5_hex md5_base64 );

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'digest' => {
      'md5' => {
        'hex' => sub {
          my $data = shift;
          return md5_hex( $data );
        },
        'base64' => sub {
          my $data = shift;
          return md5_base64( $data );
        }
      }
    }
  );
}

1;
