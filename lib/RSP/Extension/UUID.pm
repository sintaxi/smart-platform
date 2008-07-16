package RSP::Extension::UUID;

use strict;
use warnings;

use Data::UUID::Base64URLSafe;

sub provide {
  return (
    'uuid' => sub {
      my $ug  = Data::UUID::Base64URLSafe->new;
      return $ug->create_b64_urlsafe;
    }
  );
}
  

1;
