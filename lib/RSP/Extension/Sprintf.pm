package RSP::Extension::Sprintf;

use strict;
use warnings;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'sprintf' => sub {
      my $pattern = shift;
      my $result = sprintf($pattern, @_);
      return $result;
    }
  );
}

1;
