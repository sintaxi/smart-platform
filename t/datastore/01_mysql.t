#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 44;

my $objects = [
	       {
          'id' => 'hudson', 
          'name' => 'Hudson',
          'age'  => 1.5,
	       },
	       {
          'id' => 'james',
          'name' => 'James',
          'age'  => 29,
		
	       },
	       {
          'id'   => 'katrien',
          'name' => 'Katrien',
          'age'  => 32,
	       }
	      ];

#use Data::Dumper;
#diag(Dumper($objects));

my $type      = "person";
my $namespace = "test-datastore.reasonablysmart.com";

use_ok( 'RSP::Datastore' );
use_ok( 'RSP::Datastore::Namespace::MySQL' );
ok( my $ds  = RSP::Datastore->new );
ok( my $ns  = $ds->create_namespace( 'MySQL', $namespace ), "created a namespace");
diag( $ns->namespace );
ok( my $ns2 = $ds->get_namespace( 'MySQL', $namespace ), "got a namespace");

ok( $ns->write( $type, $objects->[0] ), "write an object" );

#use Data::Dumper; diag(Dumper($objects->[0]));
is_deeply( $ns->read( $type, $objects->[0]->{id} ), $objects->[0], "read an object");
#sleep 1;
ok( $ns2->remove( $type, 'hudson' ), "removed an object" );
#sleep 3; # are we getting a timing problem?
eval {
  my $badresult = $ns->read( $type, 'hudson' );
  require Data::Dumper;
  diag( Data::Dumper::Dumper( $badresult ) );
};
ok( $@, "reading an object that does not exists throws an error");
#exit;
#diag("writing multiple objects");
foreach my $obj (@$objects) {
  $ns->write( $type, $obj );
}

## simplest query possible, key = value
{
  ok( my $results = $ns->query( $type, { name => 'Katrien' } ), "queried for objects");
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 1, "got one result back");
  is( $results->[0]->{id}, "katrien", "object is the correct one (by id)" );
  is_deeply( $results->[0], $objects->[2], "object is the same as what was stored" ); 
}

## slightly more complicated, age > n
{
  ok( my $results = $ns->query( $type, { age => { '>' => 30 } } ), "queried for objects");
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 1, "got one result back");
  is( $results->[0]->{id}, "katrien", "object is the correct one (by id)" );
  is_deeply( $results->[0], $objects->[2], "object is the same as what was stored" );
}

## much more complicated age > n && age < n
{
  ok( my $results = $ns->query( $type, { age => [ { '>', 10 }, { '<', 32 } ] } ), "complex query");
  isa_ok( $results, 'ARRAY', "results is an array");
  is( scalar( @$results ), 1, "got one result back");
  is( $results->[0]->{id}, "james", "object is the correct one (by id)" );  
}

## finally, this should be an "OR"
{
  ok( my $results = $ns->query( $type, [ { name => 'James' }, { name => 'Hudson' } ] ), "OR query" );
  isa_ok( $results, "ARRAY", "results is an array");
  is( scalar(@$results), 2, "got two results back");
}

# one more query test.  Querying with nothing should yeild everything.
{
  ok( my $results = $ns->query( $type, {} ), "blank query");
  isa_ok( $results, 'ARRAY', "results is an array");
  is( scalar(@$results), 3, "got all three objects back" );
}

## we should get things out in the same order they went in
{
  ok( my $results = $ns->query( $type, {}, { sort => 'name' } ), "sort by key" );
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 3, "got three result back");
  is_deeply( $results, $objects, "order is correct")
}

## test limiting to a count.  In this case, 2.
{
  ok( my $results = $ns->query( $type, {}, { limit => 2 } ), "limit to n" );
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 2, "got two results back");
}

## finally, we need to test storing another type of object now...
{
  ok( $ns->write("foo", { id => 'afooobject', 'bar' => 'baz' }), "wrote it");
  ok( $ns->read("foo", "afooobject"), "read it");
  ok( $ns->remove("foo", "afooobject"), "removed it");
}

## and is storing and retrieving deep objects working...
{
  my $o = { id => 'anotherfoo', 'bar' => [ 'baz' ] };
  ok( $ns->write("foo", $o ), "wrote it");
  ok( my $dbo = $ns->read("foo", "anotherfoo"), "read it");
  is_deeply( $dbo, $o );
  ok( $ns->remove("foo",$o->{id}), "removed another foo...");
}

{
  foreach my $o (@$objects) {
    $ns->remove( $type, $o->{id} );
  }
}

ok( $ds->remove_namespace( 'MySQL', $namespace ), "removing namespace");

