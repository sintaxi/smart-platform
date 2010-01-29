package RSP::Extension::DataStore::MySQLQueue;

use strict;
use warnings;

use JSON::XS;
use RSP::AMQP;
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

sub write {
  my $self = shift;
  return sub {
    my $type = lc( shift );
    my $mesg = [ $self->{transaction}->{namespace}, 'write', [ $type, @_ ] ];
    my $amqp = Net::AMQP->new(user => RSP->config->{amqp}{user}, pass => RSP->config->{amqp}{pass});
    $amqp->send('smart.ds.writer' => JSON::XS::encode_json( $mesg ));
  }
}

sub remove {
  my $self = shift;
  return sub {
    my $type = lc( shift );
    my $mesg = [ $self->{transaction}->{namespace}, 'remove', [ $type, @_ ] ];
    my $amqp = Net::AMQP->new(user => RSP->config->{amqp}{user}, pass => RSP->config->{amqp}{pass});
    $amqp->send('smart.ds.writer' => JSON::XS::encode_json( $mesg ));
  }
}


1;
