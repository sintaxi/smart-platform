package RSP::Extension::DataStore::MySQL;

use strict;
use warnings;

use RSP::Datastore::Namespace::MySQL;

use RSP::Datastore;
use base 'RSP::Extension::DataStore';

sub namespace {
  my $self = shift;
  my $tx   = $self->{transaction};
  if (!$self->{namespace}) {
    my $ds = RSP::Datastore->new;
    my $ns = $ds->get_namespace( 'MySQL', $tx->hostname );
    $self->{namespace} = $ns;
  }
  return $self->{namespace};
}

1;
