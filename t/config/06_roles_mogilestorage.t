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

    Moose::Util::apply_all_roles(blessed($conf), qw(RSP::Role::Config::MogileStorage));
    ok($conf->does('RSP::Role::Config::MogileStorage'), q{Config now does MogileStorage});
    ok($conf->can(qw(mogile)), q{Config can() mogile});

    non_existant: {
        is($conf->mogile, undef, q{Non-specified mogile block returns undef});
    }

    existant: {
        ($ji, $conf) = initialize_test_js_instance({
            mogilefs => {
                trackers => '127.0.0.1:12345'
            }
        });
        
        my $val = $conf->mogile;
        isa_ok($val, q{RSP::Config::MogileFS});
        is_deeply($val->trackers, ['127.0.0.1:12345'], q{mogile returns correct trackers});
    }

}

