#    This file is part of the RSP.
#
#    The RSP is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    The RSP is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with the RSP.  If not, see <http://www.gnu.org/licenses/>.

package RSP::ObjectStore;

use strict;
use warnings;

use JSON::XS;
use Digest::MD5 'md5_hex';
use Scalar::Util qw( looks_like_number );
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

sub cache {
  my $self = shift;
  my $type = shift;
  Cache::Memcached::Fast->new( { servers => $mdservers, namespace => join(":", $self->{transaction}->host, $type) . ':' } );
}

sub write {
  my $self = shift;

  my $partsForOne = sub {
    my $type = shift;
    my $obj = shift;
    my $trans = shift;
    my $md   = $self->cache( $type );
            
    if (!$obj) { die "no object" }
    if (reftype($obj) ne 'HASH') { die "not an Object" }

    my $id    = delete $obj->{id};
    if (!$id) { die "object has no id" }

    ## if the object is transient, don't even bother going 
    ## to the database with, just put it in memcache and be done.
    ## primarily used for sessions.
    if ( $trans ) {
      if ($md->set( md5_hex( $id ), $encoder->encode( $obj ) )) {
        return ();
      } else {
        $self->log("can't find memcache, falling back to db on transient store");
      }
    }

    return (sub {
      $md->set( md5_hex( $id ), $encoder->encode( $obj ) );
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
  my $md = $self->cache( $type );
  if (!$id) { die "no id" }
  my $cached = $md->get( md5_hex( $id ) );
  if ($cached) {
    my $object = $encoder->decode( $cached );
    $object->{id} = $id;
    return $object;
  }
  my $parts = $self->storage->get( $id );        
  if (!@$parts) { return undef };
  my $dbobject = $self->parts2object( $id, $parts );
  $self->cache( $type )->set( md5_hex( $id ), $encoder->encode( $dbobject ) );
  return $dbobject;
}

sub is_sql_op {
  my $op  = shift;
  my @ops = qw( > < >= <= = != LIKE IS );
  foreach my $is_op (@ops) {
    if ( $is_op eq $op ) { return 1; }
  }
  return 0;
}

sub search {
  my $self = shift;
  my $type  = shift;
  my $query = shift;
  
  my $opts  = shift || {};
  
  my $md = $self->cache( $type );
  my $set;
  
  eval {
    $query->{type} = $type;  
    
    foreach my $key (keys %$query) {
      my $val = $query->{$key};
      my $op  = '=';
      if ( ref($val) eq 'ARRAY' && is_sql_op($val->[0])) {
        $op = shift @$val;
        if ( scalar(@$val) == 1) {
          $val = $val->[0];
        } else {
          $val = $val;
        }
      }
      my $encval = $encoder->encode( $val );
      my $nset = $self->storage->query( $key, $op, $encval );
      if ( ref($set) ) {
        $set = $set->intersection( $nset );
      } else {
        $set = $nset;
      }
    }
  };

  if ($@) {
    warn($@);
  }

  return [ ] if !$set; ## empty array
  my @objects;
  eval {
    my @members = $set->members;
    if ( $opts->{limit} && !$opts->{sort} ) {
      @members = splice(@members, 0, $opts->{limit})
    }
    foreach my $member ( @members ) {
      my $obj = $self->get( $type, $member );
      push @objects, $obj;
    }
  };
  if ($@) {
    warn($@);
  }
  
  if ( $opts->{'sort'} ) {
    my $key = $opts->{'sort'};
#    print("Sorting returned objects by $opts->{'sort'}\n");
    @objects = sort { 
      if ( looks_like_number( $a->{$key} ) ) {
        return $a->{$key} <=> $b->{$key};
      } else {
        return $a->{$key} cmp $b->{$key};
      }
    } @objects;
  }

  if ( $opts->{'reverse'} ) {
    @objects = reverse @objects;
  }
  
  if ( $opts->{'limit'} ) {
#    print("limiting returned objects to $opts->{limit}\n");
    @objects = splice(@objects, 0, $opts->{'limit'});
  }
  
  return \@objects;
}

sub remove {
  my $self = shift;
  my $type = shift;
  my $id   = shift;
  my $md   = $self->cache( $type );
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
    if (looks_like_number( $object->{$key})) {
      push @parts, [ $id, $key, $encoder->encode( 0 + $object->{$key} ) ];
    } else {
      push @parts, [ $id, $key, $encoder->encode( $object->{$key} ) ];
    }
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
