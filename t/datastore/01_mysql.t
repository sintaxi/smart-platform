#!/usr/bin/perl

use strict;
use warnings;

use Test::More (defined($ENV{MYSQL_HOST}) && defined($ENV{MYSQL_USER}) && defined($ENV{MYSQL_PASSWORD})) 
    ? (tests => 42)
    : (skip_all => q{MYSQL_HOST, MYSQL_USER and MYSQL_PASSWORD must be set for this test});
use Test::Exception;

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

my %opts = (
    host => $ENV{MYSQL_HOST},
    user => $ENV{MYSQL_USER},
    password => $ENV{MYSQL_PASSWORD},
);

basic: {
    use_ok( 'RSP::Datastore::MySQL' );
    my $ds  = RSP::Datastore::MySQL->new(namespace => $namespace, %opts);
    my $ds2 = RSP::Datastore::MySQL->new(namespace => $namespace, %opts);

    ok( $ds->write( $type, $objects->[0] ), "write an object" );

    #use Data::Dumper; diag(Dumper($objects->[0]));
    is_deeply( $ds->read( $type, $objects->[0]->{id} ), $objects->[0], "read an object");
    #sleep 1;
    ok( $ds2->remove( $type, 'hudson' ), "removed an object" );
    #sleep 3; # are we getting a timing problem?
    eval {
      my $badresult = $ds->read( $type, 'hudson' );
      require Data::Dumper;
      diag( Data::Dumper::Dumper( $badresult ) );
    };
    ok( $@, "reading an object that does not exists throws an error");
    #exit;
    #diag("writing multiple objects");
    foreach my $obj (@$objects) {
      $ds->write( $type, $obj );
    }

    ## simplest query possible, key = value
    {
      ok( my $results = $ds->query( $type, { name => 'Katrien' } ), "queried for objects");
      isa_ok( $results, 'ARRAY', "results is an array" );
      is( scalar( @$results ), 1, "got one result back");
      is( $results->[0]->{id}, "katrien", "object is the correct one (by id)" );
      is_deeply( $results->[0], $objects->[2], "object is the same as what was stored" ); 
    }

    ## slightly more complicated, age > n
    {
      ok( my $results = $ds->query( $type, { age => { '>' => 30 } } ), "queried for objects");
      isa_ok( $results, 'ARRAY', "results is an array" );
      is( scalar( @$results ), 1, "got one result back");
      is( $results->[0]->{id}, "katrien", "object is the correct one (by id)" );
      is_deeply( $results->[0], $objects->[2], "object is the same as what was stored" );
    }

    ## much more complicated age > n && age < n
    {
      ok( my $results = $ds->query( $type, { age => [ { '>', 10 }, { '<', 32 } ] } ), "complex query");
      isa_ok( $results, 'ARRAY', "results is an array");
      is( scalar( @$results ), 1, "got one result back");
      is( $results->[0]->{id}, "james", "object is the correct one (by id)" );  
    }

    ## finally, this should be an "OR"
    {
      ok( my $results = $ds->query( $type, [ { name => 'James' }, { name => 'Hudson' } ] ), "OR query" );
      isa_ok( $results, "ARRAY", "results is an array");
      is( scalar(@$results), 2, "got two results back");
    }

    # one more query test.  Querying with nothing should yeild everything.
    {
      ok( my $results = $ds->query( $type, {} ), "blank query");
      isa_ok( $results, 'ARRAY', "results is an array");
      is( scalar(@$results), 3, "got all three objects back" );
    }

    ## we should get things out in the same order they went in
    {
      ok( my $results = $ds->query( $type, {}, { sort => 'name' } ), "sort by key" );
      isa_ok( $results, 'ARRAY', "results is an array" );
      is( scalar( @$results ), 3, "got three result back");
      is_deeply( $results, $objects, "order is correct")
    }

    ## test limiting to a count.  In this case, 2.
    {
      ok( my $results = $ds->query( $type, {}, { limit => 2 } ), "limit to n" );
      isa_ok( $results, 'ARRAY', "results is an array" );
      is( scalar( @$results ), 2, "got two results back");
    }

    ## finally, we need to test storing another type of object now...
    {
      ok( $ds->write("foo", { id => 'afooobject', 'bar' => 'baz' }), "wrote it");
      ok( $ds->read("foo", "afooobject"), "read it");
      ok( $ds->remove("foo", "afooobject"), "removed it");
    }

    ## and is storing and retrieving deep objects working...
    {
      my $o = { id => 'anotherfoo', 'bar' => [ 'baz' ] };
      ok( $ds->write("foo", $o ), "wrote it");
      ok( my $dbo = $ds->read("foo", "anotherfoo"), "read it");
      is_deeply( $dbo, $o );
      ok( $ds->remove("foo",$o->{id}), "removed another foo...");
    }

    {
      foreach my $o (@$objects) {
        $ds->remove( $type, $o->{id} );
      }
    }

    {
        throws_ok {
            $ds->write("----bleh", { foo => 1 });
        } qr{(?s:datastore type names may only be named using alpha-numeric characters and underscores, starting with a letter)\n\Z}, 
            q{Incorrect type name throws error};
    }

    {
        # We search on a type that hasn't been written to yet... we should get an empty list
        is_deeply($ds->query("flibble", { fred => 'bar' }), [], q{non-written-to type search() returns empty list});
    }


    ok( $ds->remove_namespace( $namespace ), "removing namespace");
}
