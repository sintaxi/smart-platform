#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

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

my $type      = "person";
my $namespace = "test-datastore.reasonablysmart.com";

use_ok( 'RSP::Datastore' );
ok( my $ds  = RSP::Datastore->new );
ok( my $ns  = $ds->create_namespace( $namespace ), "created a namespace");
ok( my $ns2 = $ds->namespace( $namespace ), "got a namespace");
ok( $ns->write( $type, $objects->[0] ), "write an object" );
is( $ns->read( $type, $objects->[0]->{id} ), $objects->[0], "read an object");
ok( $ns2->remove( $type, $objects->[0]->{id} ), "removed an object" );
eval {
  $ns->read( $type, $objects->[0]->{id} );
};
ok( $@, "reading an object that does not exists throws an error");

diag("writing multiple objects");
foreach my $obj (@$objects) {
  $ns->write( $type, $obj );
}

## simplest query possible, key = value
{
  ok( my $results = $ns->query( $type, { name => 'katrien' } ), "queried for objects");
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 1, "got one result back");
  is( $results->[0]->{id}, "katrien", "object is the correct one (by id)" );
  is_deeply( $results->[0], $objects->[1], "object is the same as what was stored" ); 
}

## slightly more complicated, age > n
{
  ok( my $results = $ns->query( $type, { age => [ '>', 30 ] } ), "queried for objects");
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 1, "got one result back");
  is( $results->[0]->{id}, "katrien", "object is the correct one (by id)" );
  is_deeply( $results->[0], $objects->[1], "object is the same as what was stored" );
}

## much more complicated age > n && age < n
{
  ok( my $results = $ns->query( $type, { age => [ [ '>', 10 ], [ '<', 32 ] ] } ), "complex query");
  isa_ok( $results, 'ARRAY', "results is an array");
  is( scalar( @$results ), 1, "got one result back");
  is( $results->[0]->{id}, "james", "object is the correct one (by id)" );  
}

## finally, this should be an "OR"
{
  ok( my $results = $ns->query( $type, [ { id => 'james' }, { id => 'hudson' } ] ), "OR query" );
  isa_ok( $results, "ARRAY", "results is an array");
  is( scalar(@$results), 2, "got two results back");
}

## we should get things out in the same order they went in
{
  ok( my $results = $ns->query( $type, {}, { sort => 'name' } ), "sort by key" );
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 3, "got one result back");
  is_deeply( $results, $objects, "order is correct")
}

## test limiting to a count.  In this case, 2.
{
  ok( my $results = $ns->query( $type, {}, { limit => 2 } ), "limit to n" );
  isa_ok( $results, 'ARRAY', "results is an array" );
  is( scalar( @$results ), 2, "got one result back");
}


