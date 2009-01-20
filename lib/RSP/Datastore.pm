package RSP::Datastore;

use strict;
use warnings;

use RSP::Datastore::Namespace;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
}

sub create_namespace {
  my $self = shift;
  my $ns   = shift;
  if (!$ns) {
    die "no namespace";
  }
  return RSP::Datastore::Namespace->create( $ns )
}

sub get_namespace {
  my $self = shift;
  my $ns   = shift;
  if (!$ns) {
    die "no namespace";
  }
  return RSP::Datastore::Namespace->connect( $ns );
}

1;
