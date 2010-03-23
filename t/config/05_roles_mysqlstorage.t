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

    Moose::Util::apply_all_roles(blessed($conf), qw(RSP::Role::Config::MySQLStorage));
    ok($conf->does('RSP::Role::Config::MySQLStorage'), q{Config now does MySQLStorage});
    ok($conf->can(qw(mysql)), q{Config can() mysql});

    non_existant: {
        is($conf->mysql, undef, q{Non-specified mysql block returns undef});
    }

    existant: {
        ($ji, $conf) = initialize_test_js_instance({
            mysql => {
                password => 'foo',
                user => 'bar',
                host => 'some.host',
                port => 1212,
            }
        });
        
        my $val = $conf->mysql;
        isa_ok($val, q{RSP::Config::MySQL});
        is($val->password, 'foo', q{mysql returns correct password});
        is($val->user, 'bar', q{mysql returns correct user});
        is($val->host, 'some.host', q{mysql returns correct host});
        is($val->port, 1212, q{mysql returns correct port});
    }

}

