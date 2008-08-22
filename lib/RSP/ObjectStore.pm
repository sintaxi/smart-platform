package RSP::ObjectStore;

use strict;
use warnings;

use JSON::XS;
use Cache::Memcached::Fast;
use RSP::ObjectStore::Storage;
use Scalar::Util qw( reftype );


my $encoder = JSON::XS->new->utf8->allow_nonref;
my $mdservers = [ {address => '127.0.0.1:11211'} ];

sub new {
  my $class = shift;
  my $tx    = shift;
  if (!$tx) { die "no transaction" }

  my $self  = {};
  if ( !ref( $tx ) ) {
    $self->{dbfile} = $tx;
  } else {
    $self->{transaction} = $tx;  
  }

  bless $self, $class;
}

sub log {
  my $self = shift;
  if ( $self->{transaction} ) {
    $self->{transaction}->log(@_)
  } else {
    print STDERR @_, "\n";
  }
}

sub storage {
  my $self = shift;
  $self->{storage} ||= RSP::ObjectStore::Storage->new( $self->{dbfile} || $self->{transaction}->dbfile );
}

sub write {
  my $self = shift;
  my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );

  my $partsForOne = sub {
    my $type = shift;
    my $obj = shift;
    my $trans = shift;
            
    if (!$obj) { die "no object" }
    if (reftype($obj) ne 'HASH') { die "not an Object" }

    my $id    = delete $obj->{id};
    if (!$id) { die "object has no id" }

    ## if the object is transient, don't even bother going 
    ## to the database with, just put it in memcache and be done.
    ## primarily used for sessions.
    if ( $trans ) {
      if ($md->set( $id, $encoder->encode( $obj ) )) {
        return ();
      } else {
        $self->log("can't find memcache, falling back to db on transient store");
      }
    }

    return (sub {
      $md->set( $id, $encoder->encode( $obj ) );
    }, $self->object2parts( $type, $id, $obj ));
  };

  my @cache = ();
  my @parts = ();
  if (ref($_[0]) && ref($_[0]) eq 'ARRAY') {
    foreach my $elem ( @_ ) {
      my @pfo = $partsForOne->( @$elem );
      push @cache, shift @pfo;
      push @parts, @pfo;
    }
  } else {
    my @pfo = $partsForOne->( @_ );
    push @cache, shift @pfo;
    push @parts, @pfo;
  }
  
  if ( $self->storage->save( @parts ) ) {
    foreach my $cache_sub ( @cache ) {
      if ( ref( $cache_sub ) && ref($cache_sub) eq 'CODE') {
        $cache_sub->();
      }
    }    
    return 1;
  } else { $self->log("couldn't save, don't know why yet...") }

  return 0;
}

sub get {
  my $self = shift;
  my $type = shift;
  my $id   = shift;
  my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
  my $cached = $md->get( $id );
  if ($cached) {
    my $object = $encoder->decode( $cached );
    $object->{id} = $id;
    return $object;
  }
  my $parts = $self->storage->get( $id );        
  my $dbobject = $self->parts2object( $id, $parts );
}

sub search {
  my $self = shift;
  my $type  = shift;
  my $query = shift;
  my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
  
  my $set;
  foreach my $key (keys %$query) {
    my $val = $query->{$key};
    my $encval = $encoder->encode( $val );
    my $nset = $self->storage->query( $key, '=', $encval );
    if ( ref($set) ) {
      $set = $set->intersection( $nset );
    } else {
      $set = $nset;
    }
  }
  return [ ] if !$set; ## empty array

  my @objects;
  foreach my $member ( $set->members ) {
    my $parts = $self->storage->get( $member );
    push @objects, $self->parts2object( $member, $parts );
  }
 
  return \@objects;
}

sub remove {
  my $self = shift;
  my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
  my $type = shift;
  my $id   = shift;
  $md->delete( $id );
  $self->storage->delete( $id );
}

sub object2parts {
  my $self   = shift;
  my $type   = shift;
  my $id     = shift;
  my $object = shift;
  my @parts = ( [ $id, 'type', $encoder->encode( $type ) ] );
  foreach my $key (keys %$object) {
    push @parts, [ $id, $key, $encoder->encode( $object->{$key} ) ];
  }
  return @parts;
}

sub parts2object {
  my $self  = shift;
  my $id    = shift;
  my $parts = shift;
  my $object = {};
  foreach my $part ( @$parts ) {
    my $key = $part->[0];
    my $val = $part->[1];
    $object->{ $key } = $encoder->decode( $part->[1] );
  }  
  $object->{id} = $id;
  return $object;
}


1;
