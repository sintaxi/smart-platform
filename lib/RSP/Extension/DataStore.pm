package RSP::Extension::DataStore;

use strict;
use warnings;

use base 'RSP::Extension::ConfigGroup';

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

1;
