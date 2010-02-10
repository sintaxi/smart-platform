#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);

my $ji = initialize_test_js_instance({});

basic: {
    use_ok('RSP::Extension::DataStore');
    ok(RSP::Extension::DataStore->does('RSP::Role::AppMutation'), q{DataStore does RSP::Role::AppMutation});
    RSP::Extension::DataStore->apply_mutations($ji->config->_master);

    ok($ji->config->_master->does('RSP::Role::Config::MySQLStorage'), q{Config now does MySQL});
    ok($ji->config->_master->does('RSP::Role::Config::LocalStorage'), q{Config now does LocalStorage});
    ok($ji->config->_master->does('RSP::Role::Config::DataStorage'), q{Config now does DataStorage});
    ok($ji->config->does('RSP::Role::Config::DataStorage::Host'), q{Host Config now does DataStorage::Host});


    my $store = RSP::Extension::DataStore->new({ js_instance => $ji });
    ok($store->does('RSP::Role::Extension'), q{DataStore does RSP::Role::Extension});
    ok($store->does('RSP::Role::Extension::JSInstanceManipulation'), q{DataStore does RSP::Role::Extension::JSInstanceManipulation});

    {
        $store->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__datastore'}, q{DataStore has binded extension});

        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__datastore'};
        is(reftype($BIND->{datastore}), q{HASH}, q{DataStore has binded 'datastore' hash}); 
        is(reftype($BIND->{datastore}{get}), q{CODE}, q{DataStore has binded 'datastore.get' closure}); 
        is(reftype($BIND->{datastore}{remove}), q{CODE}, q{DataStore has binded 'datastore.remove' closure}); 
        is(reftype($BIND->{datastore}{'write'}), q{CODE}, q{DataStore has binded 'datastore.write' closure}); 
        is(reftype($BIND->{datastore}{search}), q{CODE}, q{DataStore has binded 'datastore.search' closure}); 
    }

}

