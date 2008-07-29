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
  my ($mbox, $private_group) = $class->connect;

  Spread::multicast( $mbox, UNRELIABLE_MESS, \@groups, 0, $coder->encode( $mesg ));
}

sub listen {
  my $class = shift;
  my @groups = @_;

  my $callback = pop @groups;
  if ( !ref($callback) || ref($callback) ne 'CODE') {
    die "no callback";
  }
  
  my ($mbox, $private_group) = $class->connect;
  my @joined = grep( Spread::join( $mbox, $_ ), @groups );
  if (@joined != @groups) { die "could not join all requested groups" }
  while( my @data = Spread::receive($mbox) ) {
    $callback->($mbox, $private_group, @data);
  }
}

sub connect {
  my ($mbox, $private_group) = Spread::connect(
    { spread_name => RSP->config->{spread}->{name}, private_name => $ug->create_b64_urlsafe }
  );
  if ( !$mbox ) {
    die("couldn't connect to spread");
  }  
  return ($mbox, $private_group);
}

1;
