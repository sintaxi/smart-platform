package RSP::Extension::DataStore;

use strict;
use warnings;

use RSP;
use base 'RSP::Extension::ConfigGroup';

sub extension_name {
  return "system.datastore";
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $self  = bless { transaction => $tx }, $class;
  return {
    'datastore' => {
      'write'  => sub { 
	my $type = lc( shift );
        return $self->namespace->write( $type, @_ );
       },
      'remove' => sub {
	my $type = lc( shift );
        return $self->namespace->remove( $type, @_ );
       },
      'search' => sub {
	my $type = lc( shift );
        return $self->namespace->query( $type, @_ );
       },
      'get'    => sub {
	my $type = lc( shift );
        return $self->namespace->read( $type, @_ );
       }
    }
  };
}

1;
