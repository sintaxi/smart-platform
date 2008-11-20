package RSP::Extension::Console;

use strict;
use warnings;

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'console' => {
      'log' => sub {
        print @_, "\n";
      }
    }
  }
}

1;
