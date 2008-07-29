package RSP::Queue::Client;

use strict;
use warnings;

use Spread;
use JSON::XS;
use Data::UUID::Base64URLSafe;

my $ug    = Data::UUID::Base64URLSafe->new;
my $coder = JSON::XS->new->allow_nonref;

sub send {
  my $class = shift;
  my $mesg  = shift;

  my @groups = @_;
  my ($mbox, $private_group) = Spread::connect(
    { spread_name => RSP->config->{spread}->{name}, private_name => $ug->create_b64_urlsafe }
  );
  if ( !$mbox ) {
    warn("couldn't connect to spread");
    return 0;
  }
  Spread::multicast( $mbox, UNRELIABLE_MESS, \@groups, 0, $coder->encode( $mesg ));
}

1;
