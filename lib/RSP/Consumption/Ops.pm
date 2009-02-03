package RSP::Consumption::Ops;

use strict;
use warnings;

use base 'RSP::Consumption';

sub init {
  my $self = shift;
  return $self->name("ops");
}

1;
