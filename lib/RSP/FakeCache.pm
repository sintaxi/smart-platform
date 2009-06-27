package RSP::FakeCache;

use strict;
use warnings;

sub new {
  my $class = shift;
  my $mesg  = "this is a fake cache";
  bless \$mesg, $class;
}

sub set {
  return 1;
}

sub get {
  return undef;
}

1;
