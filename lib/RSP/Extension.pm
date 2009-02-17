package RSP::Extension;

use strict;
use warnings;

use RSP::Error;

## most of the time this will just be the first argument...
sub providing_class {
  return shift;
}

sub should_provide {
  my $class = shift;
  my $tx    = shift;
  return 1;
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {};
}

1;
