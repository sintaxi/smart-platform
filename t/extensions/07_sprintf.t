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
    use_ok('RSP::Extension::Sprintf');

    my $spf = RSP::Extension::Sprintf->new({ js_instance => $ji });

    ok($spf->does('RSP::Role::Extension'), q{Import does RSP::Role::Extension});
    ok($spf->does('RSP::Role::Extension::JSInstanceManipulation'), q{Sprintf does RSP::Role::Extension::JSInstanceManipulation});

    {
        $spf->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__sprintf'}, q{Sprintf has binded extension}); 
        is(
            reftype($JavaScript::Context::BINDED->{'extensions.rsp__extension__sprintf'}{sprintf}), q{CODE}, 
            q{Sprintf has binded 'use' closure}
        ); 
    }

    is($spf->sprintf("%s: %d", "howdy", 12), q{howdy: 12}, q{sprintf works correctly});

    # XXX - we should probably check the format string here so that we don't get DOS'd
}

