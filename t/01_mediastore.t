#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use lib 't';
use Mock::Transaction;

use Carp qw( confess );

use_ok('RSP');
use_ok('RSP::Extension::MediaStore');

$SIG{__DIE__} = sub {
  confess @_;
};

my ($fname, $data) = ("foobar", "bazbashfoo");

my $tx = Mock::Transaction->new( 'test.smart.joyent.com' );

ok( my $ext_class = RSP::Extension::MediaStore->providing_class );
diag("providing class is $ext_class");

ok( my $provided = $ext_class->provides( $tx )->{mediastore} );

is( ref( $provided->{write} ), 'CODE' );

ok( $provided->{write}->( "test-data", $fname, $data ) );
ok( my $fobj = $provided->{get}->( "test-data", $fname ) );
ok( $provided->{remove}->( "test-data", $fname ) );

## clean up after ourselves...
ok( $ext_class->getmogile_adm->delete_domain(
	$ext_class->domain_from_tx_and_type( $tx, "test-data" )
    ), "domain should be gone...");

