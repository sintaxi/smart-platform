#!perl

use strict;
use warnings;

use lib 't';
use Mock::Transaction;
use Test::More 'no_plan';

use_ok('RSP');
use_ok('RSP::Extension::Image');

my $tx = Mock::Transaction->new( 'test.smart.joyent.com' );
ok( my $ext_class = RSP::Extension::Image->providing_class );
ok( my $bound_class = $ext_class->bind_class );
diag("class to bind is $bound_class");
ok( $bound_class->bind( $tx ) );
ok( !$tx->{context}->eval("new Image()") );
ok($@, "creating an image without any data is an error");
diag($@->{message});

1;
