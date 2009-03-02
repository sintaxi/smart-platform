package RSP::Extension::DataStore::SQLite;

use strict;
use warnings;

use RSP::Datastore::Namespace::SQLite;

use RSP::Datastore;
use base 'RSP::Extension::DataStore';

sub namespace {
  my $self = shift;
  my $tx   = $self->{transaction};
  if (!$self->{namespace}) {
    my $ds = RSP::Datastore->new;
    my $ns = $ds->get_namespace( 'SQLite', $tx->hostname );
    $self->{namespace} = $ns;
  }
  return $self->{namespace};
}

1;
