package RSP::Datastore::Namespace;

use strict;
use warnings;

use DBI;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
}

sub create {
  my $class = shift;
  my $self  = $class->new;
}

sub connect {
  my $class = shift;
  my $self  = $class->new;
}

1;
