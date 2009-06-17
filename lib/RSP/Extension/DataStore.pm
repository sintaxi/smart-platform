package RSP::Extension::DataStore;

use strict;
use warnings;

use RSP;
use base 'RSP::Extension::ConfigGroup';

sub exception_name {
  return "system.datastore";
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $self  = bless { transaction => $tx }, $class;
  return {
    'datastore' => {
      'write'  => $self->can('write')->( $self ),
      'remove' => $self->can('remove')->( $self ),
      'search' => $self->can('search')->( $self ),
      'get'    => $self->can('get')->( $self )
    }
  };
}

sub get {
  my $self = shift;
  return sub {
    my $type = lc( shift );
    return $self->namespace->read( $type, @_ );
  }
}

sub search {
  my $self = shift;
  return sub {
    my $type = lc( shift );
    return $self->namespace->query( $type, @_ );
  }
}

sub remove {
  my $self = shift;
  return sub {
    my $type = lc( shift );
    return $self->namespace->remove( $type, @_ );
  }
}

sub write {
  my $self = shift;
  return sub {
    my $type = lc( shift );
    return $self->namespace->write( $type, @_ );
  }
}

1;
