#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use lib 't';
use Mock::Transaction;

use Carp qw( confess );

$SIG{__DIE__} = sub {
  confess @_;
};

my $tx = Mock::Transaction->new( 'test.smart.joyent.com' );

use_ok('RSP::Extension::DataStore');

ok( my $ext_class = RSP::Extension::DataStore->providing_class, "got extension class");
diag("providing class is $ext_class");

ok( my $provided = $ext_class->provides( $tx )->{datastore}, "got extension provisions");
isa_ok( $provided, 'HASH' );

is( ref( $provided->{write} ), "CODE", "got a write method");
is( ref( $provided->{get} ), "CODE", "got a get method");
is( ref( $provided->{remove} ), "CODE", "got a remove method" );
is( ref( $provided->{search} ), "CODE", "got a search method" );

ok( $provided->{write}("test", { id => 'foo', 'name' => 'james' }), "wrote an object");
is_deeply( $provided->{get}("test", "foo"), { id => 'foo', 'name' => 'james' }, "got it back okay");
ok( my $result = $provided->{search}("test", { name => 'james' }), "queried okay");
is_deeply( $result, [ { id => 'foo', name => 'james' } ], "search results okay");
ok( $provided->{remove}("test", 'foo'), "removed okay");

