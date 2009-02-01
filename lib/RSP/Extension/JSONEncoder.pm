package RSP::Extension::JSONEncoder;

use strict;
use warnings;

use JSON::XS;

use base 'RSP::Extension';

my $encoders = [
  JSON::XS->new->utf8,
  JSON::XS->new->utf8->pretty
];

sub provides {
  return { 
    'json' => {
      'encode' => sub {
        my $ds  = shift;
        my $enc = shift;
        return $encoders->[$enc]->encode( $ds );
      },
      'decode' => sub {
        my $json = shift;
        return $encoders->[0]->decode( $json );
      }
    }
  }
}

1;
