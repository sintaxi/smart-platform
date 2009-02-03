package RSP::Consumption::Bandwidth;

use strict;
use warnings;

use base 'RSP::Consumption';

sub init {
  my $self = shift;
  return $self->name("bandwidth");
}

1;
