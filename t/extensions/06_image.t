#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);

my $ji = initialize_test_js_instance({});

basic: {
    use_ok('RSP::Extension::Image');

    my $image = RSP::Extension::Image->new({ js_instance => $ji });

    ok($image->does('RSP::Role::Extension'), q{Image does RSP::Role::Extension});
    ok($image->does('RSP::Role::Extension::JSInstanceManipulation'), q{Image does RSP::Role::Extension::JSInstanceManipulation});

    {
        $image->bind;

        ok($JavaScript::Context::BINDED_CLASSES->{'Image'}, q{Image had binded class});
        my $BIND = $JavaScript::Context::BINDED_CLASSES->{'Image'};
        is($BIND->{name}, 'Image', q{Bound class has correct name});
        is($BIND->{package}, 'RSP::JSObject::Image', q{Bound class is of correct package});

        is(reftype($BIND->{properties}{width}{getter}), 'CODE', q{Bound class has a 'width' property getter});
        is(reftype($BIND->{properties}{height}{getter}), 'CODE', q{Bound class has a 'height' property getter});
        
        is(reftype($BIND->{methods}{flip_horizontal}), 'CODE', q{Bound class has a 'flip_horizontal' method});
        is(reftype($BIND->{methods}{flip_vertical}), 'CODE', q{Bound class has a 'flip_vertical' method});
        is(reftype($BIND->{methods}{rotate}), 'CODE', q{Bound class has a 'rotate' method});
        is(reftype($BIND->{methods}{scale}), 'CODE', q{Bound class has a 'scale' method});
        is(reftype($BIND->{methods}{crop}), 'CODE', q{Bound class has a 'crop' method});
    }
}

