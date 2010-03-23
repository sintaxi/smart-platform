#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(blessed);

my ($ji, $conf) = initialize_test_js_instance({});

basic: {
    use Moose::Util;

    Moose::Util::apply_all_roles(blessed($conf), qw(RSP::Role::Config::LocalStorage));
    ok($conf->does('RSP::Role::Config::LocalStorage'), q{Config now does LocalStorage});
    ok($conf->can(qw(local_storage)), q{Config can() local_storage});

    non_existant: {
        is($conf->local_storage, undef, q{Non-specified localstorage block returns undef});
    }

    existant: {
        ($ji, $conf) = initialize_test_js_instance({
            localstorage => {
                data => '/foo/bar',
            }
        });
        
        my $val = $conf->local_storage;
        isa_ok($val, q{RSP::Config::LocalStorage});
        is($val->datadir, '/foo/bar', q{LocalStorage object's datadir is valid});
    }

}

