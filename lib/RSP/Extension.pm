package RSP::Extension;

use strict;
use warnings;

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
