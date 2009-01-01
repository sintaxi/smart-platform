package RSP::Extension::Sprintf;

use strict;
use warnings;

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'sprintf' => sub {
      my $mesg = shift;
      return sprintf( $mesg, @_ );
    }
  }
}

1;
