#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use mocked [qw(Data::UUID::Base64URLSafe t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);

my $ji = initialize_test_js_instance({});

basic: {
    use_ok('RSP::Extension::UUID');
    
    my $uuid = RSP::Extension::UUID->new({ js_instance => $ji });

    ok($uuid->does('RSP::Role::Extension'), q{UUID does RSP::Role::Extension});
    ok($uuid->does('RSP::Role::Extension::JSInstanceManipulation'), q{UUID does RSP::Role::Extension::JSInstanceManipulation});

    {
        $uuid->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__uuid'}, q{UUID has binded extension}); 
        is(
            reftype($JavaScript::Context::BINDED->{'extensions.rsp__extension__uuid'}{uuid}), q{CODE}, 
            q{UUID has binded 'uuid' closure}
        ); 
    }
}

uuid: {
    my $uuid = RSP::Extension::UUID->new({ js_instance => $ji }); 
    is($uuid->uuid(), q{mmm... cookies on dowels}, q{uuid works as expected});
}

