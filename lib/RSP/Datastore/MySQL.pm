package RSP::Datastore::MySQL;

use Moose;
use namespace::autoclean;
use RSP::Transaction;

use DBI;
use JSON::XS;
use SQL::Abstract;
use Set::Object;
use Carp qw( confess cluck );
use Scalar::Util::Numeric qw( isnum isint isfloat );
use Digest::MD5 qw( md5_hex );

BEGIN {
    extends 'RSP::Datastore::Base';
}

has host => (is => 'ro', isa => 'Str', required => 1);
has user => (is => 'ro', isa => 'Str', required => 1);
has password => (is => 'ro', isa => 'Str', required => 1);

has namespace => (is => 'ro', isa => 'Str', required => 1);
has namespace_sum => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_namespace_sum {
    my ($self) = @_;
    return 'db_' . md5_hex( $self->namespace );
}

has conn => (is => 'rw', lazy_build => 1);
sub _build_conn {
    my ($self) = @_;
    my $db = $self->namespace_sum;

    my $conn = DBI->connect_cached(
        "dbi:mysql:host=" . $self->host,
        $self->user, $self->password,
        { mysql_enable_utf8 => 1 }
    );
    eval {
        if(!$conn->do(sprintf("use %s", $db))){
            die "unknown db\n";
        }
    };
    if($@){
        $conn->do("create database " . $db);
        $conn->do("use " . $db);
    }
    return $conn;
}

has cache => (is => 'rw', lazy_build => 1);
sub _build_cache {
    my ($self) = @_;
    return RSP::Transaction->cache( $self->namespace );
}

sub create_type_table {
  my $self = shift;
  my $type = lc(shift);

  $self->check_type_name($type);

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

sub read_one_object {
  my $self = shift;
  my $type = lc(shift);
  my $id   = shift;

  my $obj;

  my $q_id = $self->conn->quote($id);
  my $sql = "SELECT propname, propval, thingtype FROM (";
  my @statements;
  for my $table ($self->tables_for_type( $type )){
    push @statements, "(SELECT id, propname, propval, '$table' AS thingtype FROM $table AS u_properties_$table WHERE id = $q_id)";
  }
  $sql .= join(' UNION ', @statements);
  $sql .= ") AS union_result_set WHERE id = $q_id";

    my $sth = $self->conn->prepare_cached( $sql );
    $sth->execute();
    while( my $row = $sth->fetchrow_hashref() ) {
      if (!$obj) {
        $obj = { id => $id };
      }
      my $val = $row->{propval};            
      $obj->{ $row->{ propname } } = $val ? $self->encode_output_val( $row->{thingtype}, $val ) : undef;
    }

  if (!$obj) {
    die "no such object $type:$id\n";
  }
  my $json = JSON::XS::encode_json( $obj );
  if (!$self->cache->set( "${type}:${id}",  $json )) {
    cluck("could not write $type object $id to cache");
  }
  return $obj;
}

sub remove_namespace {
    my ($self) = @_;
    $self->conn->do("DROP DATABASE " . $self->namespace_sum);
}

__PACKAGE__->meta->make_immutable;
1;
