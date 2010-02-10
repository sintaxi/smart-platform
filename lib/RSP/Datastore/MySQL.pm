package RSP::Datastore::MySQL;

use Moose;

use RSP;
use RSP::Transaction;

use DBI;
use JSON::XS;
use SQL::Abstract;
use Set::Object;
use Carp qw( confess cluck );
use Scalar::Util::Numeric qw( isnum isint isfloat );
use Digest::MD5 qw( md5_hex );

BEGIN {
    extends 'RSP::Datastore::Namespace';
}

has host => (is => 'ro', isa => 'Str', required => 1);
has user => (is => 'ro', isa => 'Str', required => 1);
has password => (is => 'ro', isa => 'Str', required => 1);

has namespace => (is => 'ro', isa => 'Str', required => 1);
has namespace_sum => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_namespace_sum {
    my ($self) = @_;
    return md5_hex( $self->namespace );
}

sub BUILD {
    my ($self) = @_;
    $self->connect();
}

sub create {
  my ($self) = @_;
  my $ns    = $self->namespace;
  my $ns_sum = $self->namespace_sum;
  
  $self->conn( $self->perform_connection );
  $self->conn->do("create database " . $ns_sum);
  $self->conn->do("use " . $ns_sum);
  $self->cache( RSP::Transaction->cache( $ns ) );
  return $self;
}

sub perform_connection {
  my ($self) = @_;
  my $host = $self->host;
  DBI->connect_cached(
		      "dbi:mysql:host=$host",
		      $self->user,
		      $self->password,
		      { mysql_enable_utf8 => 1 }
		     )
}

sub connect {
  my ($self) = @_;
  my $db    = $self->namespace_sum;
  $self->conn( $self->perform_connection );

  ## if we couldn't get a connection, chances are it's because
  ## we're missing the database, lets create one and see if that resolves it...
  ## NOTE: This commented assertion may not be true any more!
  eval {
      if (!$self->conn->do(sprintf("use %s", $db))) {
	  die "unknown db\n";
      }
  };
  if ($@) {
    $self = $self->create();
    $self->conn->do(sprintf("use %s", $db));
  } 

  $self->cache( RSP::Transaction->cache( $self->namespace ) );

  return $self;
}

sub fetch_types {
  my $self = shift;
  if (!keys %{ $self->tables }) {
    my $sth  = $self->conn->prepare_cached(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=?"
    );
    $sth->execute( $self->namespace_sum );
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
    $self->conn->do("CREATE TABLE ${type}_ids ( id CHAR(50) PRIMARY KEY )");
    $self->conn->do("CREATE INDEX ${type}_ids_idx ON ${type}_ids ( id )");
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
    die "couldn't create type tables\n";
  }
  $self->conn->commit;
  $self->tables->{$type} = 1;
}

sub remove_namespace {
    my ($self) = @_;
    $self->connect();
    $self->conn->do("DROP DATABASE " . $self->namespace_sum);
}





1;
