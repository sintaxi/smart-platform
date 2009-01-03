package RSP::Extension::Sprintf;

use strict;
use warnings;

use base 'RSP::Extension';

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
