package RSP::ObjectStore;

use strict;
use warnings;

use DBI;
use File::Spec;
use Set::Scalar;
use MIME::Base64;
use SQL::Abstract;
use Data::UUID::Base64URLSafe;

my $ug = Data::UUID::Base64URLSafe->new;
my $sa = SQL::Abstract->new;

sub new {
  my $class   = shift;
  my $db      = shift;
  if (!$db) { die "no database specified" }
  
  my $self    = {};
  bless $self, $class;

  my $dbh;
  if (-e $db) {
    ## we open the file, and run
    $dbh = DBI->connect_cached( "dbi:SQLite:dbname=$db" );
  } else {
    $dbh = DBI->connect_cached( "dbi:SQLite:dbname=$db" );
    ## we need to open the file and create the database
    $self->create_store( $dbh );
  }
  $self->{dbh}          = $dbh;
  
  return $self;
}

sub create_store {
  my $self = shift;
  my $dbh  = shift;
  local $/ = ";";
  while(my $q = <DATA>) {
    if ( $q ) {
      $q =~ s/^\s+//g;
      my $sth = $dbh->prepare( $q );
      $sth->execute();
    }
  }
}

sub dbh {
  my $self = shift;
  return $self->{dbh};
}

sub save {
  my $self  = shift;
  my @parts = @_;   
  my $sql  = "INSERT OR REPLACE INTO candomble_atom VALUES( ?, ?, ? )";
  $self->dbh->begin_work;
  my $sth = $self->dbh->prepare_cached( $sql );
  eval {
    my $p = 0;
    foreach my $part (@parts) {
      $p++;
      my ($id, $key, $val) = @$part;
      if (!$id) { die "no id on part $p" }
      $sth->execute( $id, $key, $val );
    }
  };
  if ($@) {
    $sth->finish;
    $self->dbh->rollback;
    die $@;
  }
  $sth->finish;
  $self->dbh->commit;
  return 1;
}

sub query {
  my $self = shift;
  my $key  = shift;
  my $op   = shift;
  my $val  = shift;
  
  if (! ( $key && $op && $val ) ) {
    die "need key, test, and value to query";
  }
  my ($stmt, @bind) = $sa->select(
    'candomble_atom',
    'atom_id',
    { atom_name => $key, atom_value => { $op => $val } }
  );
  my $sth = $self->dbh->prepare_cached( $stmt );
  $sth->execute( @bind );
  my $set = Set::Scalar->new;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $set->insert( $row->[0] );
  }
  $sth->finish;

  return $set;
}

sub delete {
  my $self = shift;
  my $id   = shift;
  if (!$id) { die "no id" }
  my ($stmt, @bind) = $sa->delete(
    'candomble_atom',
    { atom_id => $id }
  );
  $self->dbh->begin_work;
  eval {
    my $sth = $self->dbh->prepare_cached( $stmt );
    $sth->execute( @bind );
    $sth->finish;
  };
  if ($@) {
    $self->dbh->rollback;
    die $@;
  } else {
    $self->dbh->commit;
    return 1;
  }
}

sub get {
  my $self = shift;
  my $id   = shift;
  if (!$id) { die "no id" };
  my ($stmt, @bind) = $sa->select(
    'candomble_atom',
    ['atom_name','atom_value'],
    { atom_id => $id }
  );
  my $sth = $self->dbh->prepare_cached( $stmt );
  $sth->execute( @bind );
  my $parts = [];
  while(my $row = $sth->fetchrow_arrayref) {
    push @$parts, [ $row->[0], $row->[1] ];
  }
  return $parts;
}

sub atom_count {
  my $self = shift;
  my ($stmt, @bind) = $sa->select('candomble_atom',['count(distinct(atom_id)) as count'], {});
  my $sth = $self->dbh->prepare_cached( $stmt );
  $sth->execute( @bind );
  my $count = $sth->fetchrow_hashref->{count};
  $sth->finish;
  return $count;
}

sub key_count {
  my $self = shift;
  my ($stmt, @bind) = $sa->select('candomble_atom',['count(atom_id) as count'], {});
  my $sth = $self->dbh->prepare_cached( $stmt );
  $sth->execute( @bind );
  my $count = $sth->fetchrow_hashref->{count};
  $sth->finish;
  return $count;
}

1;

__DATA__
CREATE TABLE candomble_atom (
  atom_id, atom_name, atom_value
);

CREATE INDEX atom_id_idx
       ON candomble_atom ( atom_id );
CREATE INDEX atom_name_value_idx
       ON candomble_atom ( atom_name, atom_value );
CREATE UNIQUE INDEX atom_id_name_idx
       ON candomble_atom ( atom_id, atom_name );