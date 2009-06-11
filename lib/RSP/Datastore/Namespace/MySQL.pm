package RSP::Datastore::Namespace::MySQL;

use strict;
use warnings;

use RSP;
use RSP::Transaction;

use DBI;
use JSON::XS;
use SQL::Abstract;
use Set::Object;
use Carp qw( confess cluck );
use Scalar::Util::Numeric qw( isnum isint isfloat );
use Digest::MD5 qw( md5_hex );

use base 'RSP::Datastore::Namespace';

sub create {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->new;
  $self->namespace( md5_hex($ns) );
  my $host = RSP->config->{mysql}->{host};
  $self->conn(
      DBI->connect_cached(
	  "dbi:mysql:host=$host",
	  RSP->config->{mysql}->{username},
	  RSP->config->{mysql}->{password},
	  { mysql_enable_utf8 => 1 }
      )
  );
  $self->conn->do("create database " . $self->namespace);
  $self->conn->do("use " . $self->namespace);

  $self->cache( RSP::Transaction->cache( $ns ) );
  return $self;
}

sub connect {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->new;
  my $db    = md5_hex($ns);
  $self->namespace( $db );
  my $host = RSP->config->{mysql}->{host};
  $self->conn( DBI->connect_cached("dbi:mysql:host=$host;database=$db", RSP->config->{mysql}->{username}, RSP->config->{mysql}->{password}) );

  if (!$self->conn) {
    ## if we couldn't get a connection, chances are it's because
    ## we're missing the database, lets create one and see if that resolves it...
    $self = $class->create( $ns );
  }

  $self->cache( RSP::Transaction->cache( $ns ) );

  return $self;
}

sub fetch_types {
  my $self = shift;
  if (!keys %{ $self->tables }) {
    my $sth  = $self->conn->prepare_cached(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=?"
    );
    $sth->execute( $self->namespace );
    while( my $row = $sth->fetchrow_arrayref ) {
      my $typename = $row->[0];
      $typename =~ s/\_.+$//; 
      $self->tables->{ $typename } = 1;
    }
  }
}

sub create_type_table {
  my $self = shift;
  my $type = lc(shift);
  if (!$type) {
    RSP::Error->throw("no type");
  }
  $self->conn->begin_work;
  eval {
    $self->conn->do("CREATE TABLE ${type}_ids ( id CHAR(50) )");
    $self->conn->do("CREATE TABLE ${type}_prop_i ( id CHAR(50), propname CHAR(25), propval BIGINT ) TYPE=InnoDB");
    $self->conn->do("CREATE INDEX ${type}_prop_i_id_propname ON ${type}_prop_i (id, propname)");
    $self->conn->do("CREATE INDEX ${type}_prop_i_propname_propval ON ${type}_prop_i (propname, propval)");

    $self->conn->do("CREATE TABLE ${type}_prop_f ( id CHAR(50), propname CHAR(25), propval FLOAT ) TYPE=InnoDB");
    $self->conn->do("CREATE INDEX ${type}_prop_f_id_propname ON ${type}_prop_f (id, propname)");
    $self->conn->do("CREATE INDEX ${type}_prop_f_propname_propval ON ${type}_prop_f (propname, propval)");

    $self->conn->do("CREATE TABLE ${type}_prop_s ( id CHAR(50), propname CHAR(25), propval VARCHAR(256) ) TYPE=InnoDB");
    $self->conn->do("CREATE INDEX ${type}_prop_s_id_propname ON ${type}_prop_s (id, propname)");
    $self->conn->do("CREATE INDEX ${type}_prop_s_propname_propval ON ${type}_prop_s (propname, propval)");

    $self->conn->do("CREATE TABLE ${type}_prop_o ( id CHAR(50), propname CHAR(25), propval TEXT ) TYPE=InnoDB");
    $self->conn->do("CREATE INDEX ${type}_prop_o_id_propname ON ${type}_prop_o (id, propname)");
  };
  if ($@) {
    $self->conn->rollback;
    RSP::Error->throw("couldn't create type tables");
  }
  $self->conn->commit;
  $self->tables->{$type} = 1;
}

sub delete {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->connect( $ns );
  $self->conn->do("DROP DATABASE " . $self->namespace);
}





1;
