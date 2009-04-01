package RSP::Datastore::Namespace;

use strict;
use warnings;

use RSP::Error;
use Scalar::Util::Numeric qw( isnum isint isfloat );
use Carp qw( cluck );
use base 'Class::Accessor::Chained';

__PACKAGE__->mk_accessors(qw(namespace conn tables sa cache));

sub new {
  my $class = shift;
  my $self  = { tables => {}, sa => SQL::Abstract->new };
  bless $self, $class;
}

sub exception_name {
  return "datastore";
}

sub fetch_types {
  die "abstract method fetch_types called";
}

sub has_type_table {
  my $self = shift;
  my $type = lc(shift);
  if (!$type) {
    RSP::Error->throw("no type");
  }
  if (!keys %{$self->tables}) {
    $self->fetch_types;
  }
  return $self->tables->{$type}
}

sub types {
  my $self = shift;
  if (!keys %{$self->tables}) { $self->fetch_types }
  return keys %{$self->tables};
}


sub tables_for_type {
  my $self = shift;
  my $type = lc(shift);
  if (!$type) {
    RSP::Error->throw("no type");
  }
  my @suffixes = qw( f s o i );
  my @tables = ();
  foreach my $suffix (@suffixes) {
    push @tables, sprintf("%s_prop_%s", $type, $suffix );
  }
  return @tables;
}

sub remove {
  my $self = shift;
  my $type = lc(shift);
  my $id   = shift;
  if (!$type) {
    RSP::Error->throw("no type");
  }
  if (!$id) {
    RSP::Error->throw("no id");
  }
  $self->conn->begin_work;
  eval {
    $self->_remove_in_transaction( $type, $id );
    if ( !$self->cache->remove( "${type}:${id}" ) ) {
      cluck "Could not remove from cache!";
    }
  };
  if ($@) {
    $self->conn->rollback;
    RSP::Error->throw($@);
  }
  $self->conn->commit;
  return 1;
}

sub _remove_in_transaction {
  my $self = shift;
  my $type = lc(shift);
  my $id   = shift;
  my $where  = { id => $id };
  foreach my $table ($self->tables_for_type( $type )) {
    my ($stmt, @bind) = $self->sa->delete($table, $where);
    my $sth = $self->conn->prepare_cached( $stmt );
    $sth->execute( @bind );
    $sth->finish;
  }
  my ($stmt, @bind) = $self->sa->delete("${type}_ids", $where);
  my $sth = $self->conn->prepare_cached( $stmt );
  $sth->execute(@bind);
  $sth->finish;
}

sub read {
  my $self = shift;
  my $type = lc(shift);
  my $id   = shift;
  if (!$type) {
    RSP::Error->throw("no type");
  }
  if (!$id) {
    RSP::Error->throw("no id");
  }

  my $cache  = $self->cache->get( "${type}:${id}" );
  if ( $cache ) {
    my $cached = eval { JSON::XS::decode_json( $cache ); };
    return $cached;
  }

  if (!$self->has_type_table( $type )) {
    RSP::Error->throw("no such type");
  } else {
    my $obj = $self->read_one_object( $type, $id );
    if (!$obj) {
      RSP::Error->throw("no such object");
    }
    return $obj;
  }
}

sub encode_output_val {
  my $self  = shift;
  my $table = shift;
  my $val   = shift;
  my $chr   = substr($table, -1, 1 );
#  print "CHR FOR $val is $chr\n";
  if ( $chr eq 'o' ) {
    return JSON::XS::decode_json( $val );
  } elsif ( $chr eq 'i' ) {
    return 0 + $val;
  } elsif ( $chr eq 'f' ) {
    return 0.00 + $val;
  } elsif ( $chr eq 's' ) {
    return "".$val;
  } else {
    return $val;
  }
}


sub read_one_object {
  my $self = shift;
  my $type = lc(shift);
  my $id   = shift;
  my $fields = ['propname', 'propval'];
  my $where  = { id => $id };
  
  #my ($stmt, @bind) = $self->sa->select("${type}_ids", ['count(id)'], $where);
  #my $sth = $self->conn->prepare($stmt);
  #$sth->execute(@bind);
  #if ( $sth->fetchrow_arrayref()->[0] < 1 ) {
  #  confess "no such object";
  #} else {
  #  print "we have ids!";
  #}
  
  my $obj;
  foreach my $table ($self->tables_for_type( $type )) {
    my ($stmt, @bind) = $self->sa->select($table, $fields, $where);
    my $sth = $self->conn->prepare_cached( $stmt );
    $sth->execute( @bind );
    while( my $row = $sth->fetchrow_hashref() ) {
      if (!$obj) {
        $obj = { id => $id };
      }
      my $val = $row->{propval};            
      $obj->{ $row->{ propname } } = $self->encode_output_val( $table, $val );
    }
    $sth->finish;
  }
  if (!$obj) {
    RSP::Error->throw("no such object $type:$id");
  }
  my $json = JSON::XS::encode_json( $obj );
  if (!$self->cache->set( "${type}:${id}",  $json )) {
    cluck("could not write $type object $id to cache");
  }
  return $obj;
}

sub write {
  my $self  = shift;
  my $type  = shift;
  my $obj   = shift;
  my $trans = shift;
  if (!$type) {
    RSP::Error->throw("no type");
  }
  if (!$obj) {
    RSP::Error->throw("no object");
  }
  if ( $trans ) {
    my $id = $obj->{id};
    if ( $self->cache->set( "${type}:${id}", JSON::XS::encode_json( $obj ) ) ) {
      return 1;
    } else {
      cluck("could not write transient $type object $id to cache, falling back to persistent store");
    }
  }
  
  if (!$self->has_type_table( $type )) {
    $self->create_type_table( $type );
    $self->write_one_object( $type, $obj );
  } else {
    $self->write_one_object( $type, $obj );
  }
  return 1;
}

sub write_one_object {
  my $self = shift;
  my $type = lc(shift);
  my $obj  = shift;
  my $id   = $obj->{id};
  if (!$id) {
    RSP::Error->throw("object has no id");
  }
  $self->conn->begin_work;
  eval {
    my $fields = [ 'id', 'propame', 'propval' ];
    $self->_remove_in_transaction( $type, $id );
    foreach my $key (keys %$obj) {
      next if $key eq 'id';
      my $val = $obj->{$key};
      my $svals = { id => $id,  propname => $key, propval => $val };
      my $table = $self->table_for( $type, value => $val );      
      if ( $self->valtype( $val ) eq 'ref' ) {
        $svals->{propval} = JSON::XS::encode_json( $val );
      }
      my ($stmt, @bind) = $self->sa->insert($table, $svals);
      my $sth = $self->conn->prepare_cached($stmt);      
      $sth->execute(@bind);
      $sth->finish;
    }
    my ($stmt, @bind) = $self->sa->insert("${type}_ids", { id => $id });
    my $sth = $self->conn->prepare_cached($stmt);
    $sth->execute(@bind);
    $sth->finish;
    if (!$self->cache->set( "${type}:${id}", JSON::XS::encode_json( $obj ) )) {
      cluck "could not write $type object $id to cache";
    } 
  };
  if ($@) {
    $self->conn->rollback;
    RSP::Error->throw($@);
  }
  $self->conn->commit;
  return 1;
}

sub query {
  my $self  = shift;
  my $type  = shift;
  my $query = shift;
  my $opts  = shift || {};
  if (!$type) {
    RSP::Error->throw("no type");
  }
  if (!$query) {
    RSP::Error->throw("no query");
  }
  my @objects;
  if (ref($query) eq 'HASH') {
    if (keys %$query == 0) {
      my $set = $self->all_ids_for( $type );
      foreach my $id (@$set) {
	push @objects, $self->read($type, $id);
      }
    } else {
      my $set = $self->query_set_and( $type, $query );
      foreach my $id (@$set) {
	push @objects, $self->read( $type, $id );
      }
    }
  } elsif (ref($query) eq 'ARRAY') {
    my $set = $self->query_set_or( $type, $query );
    foreach my $id (@$set) {
      push @objects, $self->read( $type, $id );
    }
  }

  if ( $opts->{sort} ) {
    ## okay, time to get sorting...
    @objects = sort { $a->{ $opts->{sort} } cmp $b->{ $opts->{sort } } } @objects;
  }

  if ( $opts->{limit} ) {
#    print "LIMITING ARRAY TO $opts->{limit}\n";
#    print "STARTING SIZE IS ", scalar(@objects), "\n";
    my $offset = 0;
    if ($opts->{offset}) {
      $offset = $opts->{offset};
    }
    splice(@objects, $offset, $opts->{limit} - 1 );
  }

  return \@objects;
}

sub all_ids_for {
  my $self = shift;
  my $type = lc(shift);

  my $set = Set::Object->new;
  
  if ( !$self->has_type_table( $type ) ) {
    return $set;
  } 
  
  my ($stmt, @bind) = $self->sa->select("${type}_ids", ['id']);
  my $sth = $self->conn->prepare_cached($stmt);
  $sth->execute( @bind );
  while( my $row = $sth->fetchrow_arrayref() ) {
    $set->insert( $row->[0] );
  }
  $sth->finish;
  return $set;
}

sub query_set_or {
  my $self = shift;
  my $type = lc(shift);
  my $query = shift;

  my @sets;
  foreach my $val (@$query) {
    my @qsets = $self->query_set_and( $type, $val );
    if (@qsets) {
      push @sets, @qsets;
    }
  }
  if (!@sets) {
    return Set::Object->new;
  } else {
    my $set = shift @sets;
    while( my $nset = shift @sets ) {
      $set = $set->union( $nset );
    }
    return $set;
  }  
}

sub query_set_and {
  my $self = shift;
  my $type = lc(shift);
  my $query = shift;

  my @sets;
  foreach my $key (keys %$query) {
    my @qsets = $self->query_one_set( $type, $key, $query->{$key} );    
    if (@qsets) {
      push @sets, @qsets;
    }
  }
  if (!@sets) {
    return Set::Object->new;
  } else {
    my $set = shift @sets;
    while( my $nset = shift @sets ) {
      $set = $set->intersection( $nset );
    }
    return $set;
  }
}

sub table_for {
  my $self  = shift;
  my $type  = shift;
  my $args  = { @_ };
  if (!exists $args->{value}) { 
    RSP::Error->throw("no value");
  }
  my $dt = $self->valtype( $args->{value} );
  my $lookup = {
		'int' => 'i',
		'float' => 'f',
		'ref' => 'o',
		'string' => 's'
  };
  return "${type}_prop_$lookup->{$dt}";
}

sub valtype {
  my $self = shift;
  my $val  = shift;
  if ( ref( $val ) ) {
    return 'ref';
  } elsif (isnum($val)) {
    if ( isint( $val ) ) {
      return 'int';
    } else {
      return 'float';
    }
  } else {
    return 'string';
  }
}

sub query_one_set {
  my $self = shift;
  my $type = lc(shift);
  my $key  = shift;
  my $val  = shift;
  my $table;
  my $set  = Set::Object->new;

  ##
  ## this is hairy.  we have to figure out what datatype we are querying.
  ##
  if ( !ref( $val ) ) {
    $table = $self->table_for( $type, value => $val );
  } else {
    if ( ref($val) eq 'HASH' && keys %$val == 1) {
      my ($hval) = values (%$val);
      $table = $self->table_for( $type, value => $hval );
    } elsif( ref($val) eq 'ARRAY' ) {
      ## at this point it's easier to duck and recursively query...
      my @csets = ();
      foreach my $elem (@$val) {
	push @csets, $self->query_set_and( $type, { $key => $elem } );
      }
      return @csets;
    }
  }

  my ($stmt, @bind) = $self->sa->select($table, ['id'], { propname => $key, propval => $val });
  my $sth = $self->conn->prepare_cached( $stmt );
  $sth->execute(@bind);
  while( my $row = $sth->fetchrow_arrayref() ) {
    $set->insert($row->[0]);
  }
  $sth->finish;
#  print "SET FROM QUERY $stmt (@bind) IS ", join(", ", @$set), "\n";
  return $set;
}

1;
