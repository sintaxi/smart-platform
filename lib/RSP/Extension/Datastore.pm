package RSP::Extension::Datastore;

use strict;
use warnings;

use RSP::ObjectStore;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'datastore' => {
    
      'write'  => sub { my $os = RSP::ObjectStore->new( $tx ); $os->write(@_) },
      'remove' => sub { my $os = RSP::ObjectStore->new( $tx ); $os->remove( @_ ) },
      'search' => sub { my $os = RSP::ObjectStore->new( $tx ); $os->search( @_ ) },
      'get'    => sub { my $os = RSP::ObjectStore->new( $tx ); $os->get( @_ ); },

    }
  );
}

1;
