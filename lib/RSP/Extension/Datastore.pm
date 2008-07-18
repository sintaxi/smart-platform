package RSP::Extension::Datastore;

use strict;
use warnings;

use JSON::XS;
use RSP::ObjectStore;
use Scalar::Util qw( reftype );

my $encoder = JSON::XS->new->utf8->allow_nonref;

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
        my $type = shift;
        my $obj = shift;

        if (!$obj) { die "no object" }
        if (reftype($obj) ne 'HASH') { die "not an Object" }
  
        my $id    = delete $obj->{id};
        if (!$id) { die "object has no id" }

        my @parts = ( [ $id, 'type', $encoder->encode( $type ) ] );
        foreach my $key (keys %$obj) {
          push @parts, [ $id, $key, $encoder->encode( $obj->{$key} ) ];
        }
        my $rd = $class->getrd( $tx );
        return $rd->save( @parts );        
      },
      
      'remove' => sub {
        my $type = shift;
        my $id   = shift;
        $class->getrd( $tx )->delete( $id );
      },

      'search' => sub {
        my $type  = shift;
        my $query = shift;
        
        my $set;
        foreach my $key (keys %$query) {
          my $val = $query->{$key};
          my $encval = $encoder->encode( $val );
          my $nset = $class->getrd( $tx )->query( $key, '=', $encval );
          if ( $set ) {
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
        my $parts = $class->getrd( $tx )->get( $id );        
        return $class->parts2object( $id, $parts );
      }
    }
  );
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
