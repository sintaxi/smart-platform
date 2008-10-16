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
      $tx->log("RESULT of sprintf(@_) is $result");
      return $result;
    }
  );
}

1;
