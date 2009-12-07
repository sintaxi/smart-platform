package RSP::Datastore::Namespace::SQLite;

use strict;
use warnings;

use RSP;
use RSP::Transaction;

use DBI;
use JSON::XS;
use File::Path;
use SQL::Abstract;
use Set::Object;
use Carp qw( confess cluck );
use Scalar::Util::Numeric qw( isnum isint isfloat );
use Digest::MD5 qw( md5_hex );

use base 'RSP::Datastore::Namespace';

__PACKAGE__->mk_accessors(qw( dbfile ));

sub create {
  my $class = shift;
  my $ns    = shift;
  $class->connect( $ns );
}

sub connect {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->new;
  my $db    = md5_hex( $ns );

  $self->namespace( $db );

  my $dir = RSP->config->{localstorage}->{data} // '';
  my $dbd = File::Spec->catfile( $dir, substr($db, 0, 2) );
  my $dbf = File::Spec->catfile( $dbd, $ns );
  mkpath( $dbd );
  $self->dbfile( $dbf );
  $self->conn( DBI->connect_cached( "dbi:SQLite:dbname=$dbf", "", "", { sqlite_unicode => 1 } ) );
  $self->cache( RSP::Transaction->cache( $ns ) );
  return $self;
}

sub fetch_types {
  my $self = shift;
  if (!keys %{ $self->tables }) {
    my $sth  = $self->conn->prepare_cached(
      "SELECT tbl_name FROM sqlite_master"
    );
    $sth->execute();
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
    $self->conn->do("CREATE TABLE ${type}_prop_i ( id CHAR(50), propname CHAR(25), propval BIGINT )");
    $self->conn->do("CREATE INDEX ${type}_prop_i_id_propname ON ${type}_prop_i (id, propname)");
    $self->conn->do("CREATE INDEX ${type}_prop_i_propname_propval ON ${type}_prop_i (propname, propval)");

    $self->conn->do("CREATE TABLE ${type}_prop_f ( id CHAR(50), propname CHAR(25), propval FLOAT )");
    $self->conn->do("CREATE INDEX ${type}_prop_f_id_propname ON ${type}_prop_f (id, propname)");
    $self->conn->do("CREATE INDEX ${type}_prop_f_propname_propval ON ${type}_prop_f (propname, propval)");

    $self->conn->do("CREATE TABLE ${type}_prop_s ( id CHAR(50), propname CHAR(25), propval VARCHAR(256) )");
    $self->conn->do("CREATE INDEX ${type}_prop_s_id_propname ON ${type}_prop_s (id, propname)");
    $self->conn->do("CREATE INDEX ${type}_prop_s_propname_propval ON ${type}_prop_s (propname, propval)");

    $self->conn->do("CREATE TABLE ${type}_prop_o ( id CHAR(50), propname CHAR(25), propval TEXT )");
    $self->conn->do("CREATE INDEX ${type}_prop_o_id_propname ON ${type}_prop_o (id, propname)");
  };
  if ($@) {
    $self->conn->rollback;
    RSP::Error->throw("couldn't create type tables ($@)");
  }
  $self->conn->commit;
  $self->tables->{$type} = 1;
}

sub delete {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->connect( $ns );
  unlink( $self->dbfile );
}

1;
