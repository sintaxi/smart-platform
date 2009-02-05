package RSP::Extension::DataStore::MySQL;

use strict;
use warnings;

use RSP::Datastore;
use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $self  = bless { transaction => $tx }, $class;
  return {
    'datastore' => {
      'write'  => sub { 
        $_[0] = lc($_[0]);
        return $self->namespace->write( @_ );
       },
      'remove' => sub {
        $_[0] = lc($_[0]);
        return $self->namespace->remove( @_ );
       },
      'search' => sub { 
        $_[0] = lc($_[0]);
        return $self->namespace->query( @_ );
       },
      'get'    => sub {
        $_[0] = lc($_[0]);
        return $self->namespace->read( @_ );
       }
    }
  };
}

sub namespace {
  my $self = shift;
  my $tx   = $self->{transaction};
  if (!$self->{namespace}) {
    my $ds = RSP::Datastore->new;
    my $ns = $ds->get_namespace( $tx->host->hostname );
    $self->{namespace} = $ns;  
  }
  return $self->{namespace};
}

1;
