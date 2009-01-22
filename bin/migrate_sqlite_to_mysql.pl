#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use JSON::XS;
use File::Spec;
use SQL::Abstract;
use Data::Dumper;
use RSP::Datastore;
use RSP::ObjectStore;
use RSP::ObjectStore::Storage;

my $ns = shift;
if (!$ns) {
  print "no namespace";
  exit 255;
}

my $dbpath = shift;
if (!$dbpath) {
  print "no dbpath";
  exit 255;
}

my $ms = RSP::Datastore->new;
my $ds = eval { $ms->create_namespace( $ns ); } || $ms->get_namespace( $ns );

my $sa    = SQL::Abstract->new;
my $table = 'candomble_atom';
my $key   = 'atom_name';
my $id    = 'atom_id';
my $val   = 'atom_value';
my $file  = File::Spec->catfile( $dbpath, $ns, "data.db" );
my $dsn   = "dbi:SQLite:dbname=$file";

my $oss = RSP::ObjectStore::Storage->new( $file );
my $dbh = $oss->dbh;

my @types;
{
  my ($stmt, @bind) = $sa->select( $table, [ "distinct($val)" ], { $key => "type" } );
  my $sth = $dbh->prepare( $stmt );
  $sth->execute(@bind);
  while(my $row = $sth->fetchrow_arrayref()) {
    push @types, $row->[0];
  }
  $sth->finish;
}
print "Types are: ", join(", ", @types), "\n";

foreach my $type (@types) {
  next if $type =~ /session/i;
  eval {
    my $set = $oss->query('type', '=', $type);
    my @ids = $set->members;
    my @objs = ();
    foreach my $id (@ids) {
      push @objs, RSP::ObjectStore->parts2object( $id, $oss->get( $id ) );
    }
    $type =~ s/^\"//;
    $type =~ s/\"$//;
    foreach my $obj (@objs) {
      print "writing $type object $obj->{id}\n";
      $ds->write( $type, $obj );
    }
  };
}
