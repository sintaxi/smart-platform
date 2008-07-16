package RSP::Extension::JSON;

use strict;
use warnings;

use JSON::XS;

my $encoders = [  JSON::XS->new->utf8, JSON::XS->new->utf8->pretty];

sub provide {
  return (
    'json' => {
      'encode' => sub {
        my $data   = shift;
        return $encoders->[shift||0]->encode( $data );        
      },
      'decode' => sub {
        my $text = shift;
        return $encoders->[0]->decode( $text );
      }
    }
  );
}

1;
