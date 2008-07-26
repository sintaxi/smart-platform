package RSP::Extension::Datastore;

use strict;
use warnings;

use JSON::XS;
use RSP::ObjectStore;
use Cache::Memcached::Fast;
use Scalar::Util qw( reftype );

my $encoder = JSON::XS->new->utf8->allow_nonref;
my $mdservers = [ {address => '127.0.0.1:11211'} ];

sub getrd {
  my $class = shift;
  my $tx    = shift;
  my $rd  = $tx->{dbh} ||= RSP::ObjectStore->new( $tx->dbfile );
  return $rd;
}

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'datastore' => {
    
      'write' => sub {        
        my $partsForOne = sub {
          my $type = shift;
          my $obj = shift;
          my $trans = shift;
          my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
                  
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
            } else { $tx->log("can't find memcache, falling back to db on transient store"); }
          }
  
          return (sub {
            $md->set( $id, $encoder->encode( $obj ) );
          }, $class->object2parts( $type, $id, $obj ));
        };

        my @cache = ();
        my @parts = ();
        if (ref($_[0]) && ref($_[0]) eq 'ARRAY') {
          foreach my $elem ( $_[0] ) {
            my @pfo = $partsForOne->( @$elem );
            push @cache, shift @pfo;
            push @parts, @pfo;
          }
        } else {
          my @pfo = $partsForOne->( @_ );
          push @cache, shift @pfo;
          push @parts, @pfo;
        }
        
        my $rd = $class->getrd( $tx );
        if ( $rd->save( @parts ) ) {
          foreach my $cache_sub ( @cache ) {
            $cache_sub->();
          }
          return 1;        
        }
        return 0;
      },
      
      'remove' => sub {
        my $type = shift;
        my $id   = shift;
        my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
        $md->delete( $id );
        $class->getrd( $tx )->delete( $id );
      },

      'search' => sub {
        my $type  = shift;
        my $query = shift;
        my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
        
        my $set;
        foreach my $key (keys %$query) {
          my $val = $query->{$key};
          my $encval = $encoder->encode( $val );
          my $nset = $class->getrd( $tx )->query( $key, '=', $encval );
          if ( ref($set) ) {
            $set = $set->intersection( $nset );
          } else {
            $set = $nset;
          }
        }
        return [ ] if !$set; ## empty array

        my @objects;
        foreach my $member ( $set->members ) {
          my $parts = $class->getrd( $tx )->get( $member );
          push @objects, $class->parts2object( $member, $parts );
        }
       
        return \@objects;
      },
      
      'get'    => sub {
        my $type = shift;
        my $id   = shift;
        my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
        my $cached = $md->get( $id );
        if ($cached) { return $encoder->decode( $cached ); }
        my $parts = $class->getrd( $tx )->get( $id );        
        return $class->parts2object( $id, $parts );
      }
    }
  );
}

sub object2parts {
  my $class  = shift;
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
  my $class = shift;
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
