package RSP::Extension::Console;

use strict;
use warnings;

use base 'RSP::Extension';

sub extension_name {
  return "system.console";
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'console' => {
      'log' => sub {
        my $mesg = shift;
        $tx->log( $mesg );
      }
    }
  }
}

1;
