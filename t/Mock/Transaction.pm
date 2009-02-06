package Mock::Transaction;

use strict;
use warnings;

use JavaScript;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  $self->{runtime} = JavaScript::Runtime->new;
  $self->{context} = $self->{runtime}->create_context;
  $self->{namespace} = shift;
  return $self;
}

sub namespace {
  my $self = shift;
  return $self->{namespace};
}

sub context {
  my $self = shift;
  return $self->{context};
}

1;
