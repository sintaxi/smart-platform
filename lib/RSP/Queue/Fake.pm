package RSP::Queue::Fake;

use strict;
use warnings;

use JSON::XS;

my $coder = JSON::XS->new->allow_nonref;

sub send {
  my $class  = shift;
  my $mesg   = shift;
  my @groups = @_;
  print STDERR sprintf("[%s] %s\n", join(",", @groups), $coder->encode( $mesg ));
}

1;
