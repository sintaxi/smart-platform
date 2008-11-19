package RSP::Extension::UUID;

use strict;
use warnings;

use Data::UUID::Base64URLSafe;

my $ug = Data::UUID::Base64URLSafe->new;

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'uuid' => sub {
      return $ug->create_b64_urlsafe;
    }
  }
}

1;
