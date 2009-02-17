package RSP::Error;

use strict;
use warnings;

sub throw {
  my $class = shift;
  my $mesg  = shift;
  my $pack  = caller();
  die { message => $mesg, fileName => $pack };
}

1;

