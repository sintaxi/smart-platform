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

ok( $provided->{write}->( $fname, $data ) );
ok( my $fobj = $provided->{get}->( $fname ) );
ok( $provided->{remove}->( $fname ) );

ok( $ext_class->getmogile_adm->delete_domain($tx->hostname), "domain should be gone...");

