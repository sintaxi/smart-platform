package RSP::Extension::UUID;

use strict;
use warnings;

use Data::UUID::Base64URLSafe;
use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'uuid' => sub {
      my $ug = Data::UUID::Base64URLSafe->new;
      return $ug->create_b64_urlsafe;
    }
  }
}

1;
