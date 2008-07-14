package RSP::Extension::Console;

use strict;
use warnings;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return ( console => {
    log => sub {
      my $mesg = shift;
      $tx->log( $mesg );
    }
  });
}

1;
