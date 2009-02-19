package RSP::Extension::JSONEncoder;

use strict;
use warnings;

use JSON::XS;

use base 'RSP::Extension';

my $encoders = [
  JSON::XS->new->utf8,
  JSON::XS->new->utf8->pretty
];

sub extension_name {
  return "system.json";
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  return { 
    'json' => {
      'encode' => sub {
        my $ds  = shift;
        my $enc = shift;
	my $ret = eval { $encoders->[$enc]->encode( $ds ) };
	if ($@) {
	  $tx->log("error: $@");
	  RSP::Error->throw( $@ );
	}
	return $ret;
      },
      'decode' => sub {
        my $json = shift;
        my $ret  = $encoders->[0]->decode( $json );
	if ($@) {
	  $tx->log("error: $@");
	  RSP::Error->throw( $@ );
	}
	return $ret;
      }
    }
  }
}

1;
