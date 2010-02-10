package RSP::Datastore::SQLite;

use Moose;

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

BEGIN {
    extends 'RSP::Datastore::Namespace';
}

has datadir => (is => 'ro', isa => 'Str', required => 1);
has dbfile => (is => 'rw', isa => 'Str');
has namespace => (is => 'ro', isa => 'Str', required => 1);
has namespace_sum => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_namespace_sum {
    my ($self) = @_;
    return md5_hex( $self->namespace );
}

sub BUILD {
    my ($self) = @_;
    $self->connect($self->namespace);
}

sub create {
  my ($self) = @_;
  $self->connect( $self->namespace );
}

sub connect {
  my ($self) = @_;
  my $ns    = $self->namespace;
  my $db    = $self->namespace_sum;

  my $dir = $self->datadir;

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
    die "no type\n";
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
    chomp($@);
    die "couldn't create type tables: $@\n";
  }
  $self->conn->commit;
  $self->tables->{$type} = 1;
}

sub remove_namespace {
    my ($self) = @_;
    unlink( $self->dbfile );
}

1;
