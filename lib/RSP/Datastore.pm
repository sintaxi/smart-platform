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
  my $type = shift;
  my $ns   = shift;
  if (!$ns) {
    die "no namespace";
  }
  my $cl = 'RSP::Datastore::Namespace::' . $type;
  return $cl->create( $ns )
}

sub get_namespace {
  my $self = shift;
  my $type = shift;
  my $ns   = shift;
  if (!$ns) {
    die "no namespace";
  }
  my $cl = 'RSP::Datastore::Namespace::' . $type;
  return $cl->connect( $ns );
}

sub remove_namespace {
  my $self = shift;
  my $type = shift;
  my $ns   = shift;
  if (!$ns) {
    die "no namespace";
  }
  my $cl = 'RSP::Datastore::Namespace::' . $type;
  $cl->delete( $ns );
}

1;
