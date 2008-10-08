package RSP::Queue::Fake;

use strict;
use warnings;

use JSON::XS;

my $coder = JSON::XS->new->allow_nonref;

sub send {
  my $class  = shift;
  my $mesg   = shift;
  my @groups = @_;
#  my @realgroups = grep { $_ eq "log" } @groups;
#  if ( @realgroups ) {
    print STDERR sprintf("[%s] %s\n", join(",", @groups), $mesg);
#  }
}

1;
