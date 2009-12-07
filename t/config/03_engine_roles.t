#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use Carp qw( confess );

use Clone qw(clone);
use Scalar::Util qw(reftype);

use RSP::Config;
use_ok("RSP::JS::Engine::SpiderMonkey");

basic: {
    RSP::JS::Engine::SpiderMonkey->initialize();
    ok(RSP::Config->does("RSP::Role::Config::SpiderMonkey"), q{Config now knows about SpiderMonkey});
#    ok(RSP::Config::Host->does("RSP::Role::Config::SpiderMonkey::Host"), q{Host Config now knows about SpiderMonkey});
}

our $config = {
};

config_options: {
    my $conf = RSP::Config->new({config => $config });
    can_ok($conf, qw(use_e4x use_strict));

    {
        is($conf->use_e4x, 1, q{use_e4x defaults to true});
        local $config = clone($config);
        $conf = RSP::Config->new({config => $config });
        $config->{_}{spidermonkey_use_e4x} = 0;
        is($conf->use_e4x, 0, q{use_e4x from config is correct});
    }

    $conf = RSP::Config->new({ config => $config });

    {
        is($conf->use_strict, 1, q{use_strict defaults to true});
        local $config = clone($config);
        $conf = RSP::Config->new({config => $config });
        $config->{_}{spidermonkey_use_strict} = 0;
        is($conf->use_strict, 0, q{use_strict from config is correct});
    }
}

$config = {
    'host:foo' => {
        js_engine => 'SpiderMonkey',
    },
    'host:bar' => {
        js_engine => 'none',
    },
};

basic_host:{
    my $foo = RSP::Config->new({ config => $config })->host('foo');
    my $bar = RSP::Config->new({ config => $config })->host('bar');

    ok($foo->does('RSP::Role::Config::SpiderMonkey::Host'), q{host 'foo' does spidermonkey config});
    ok(!$bar->does('RSP::Role::Config::SpiderMonkey::Host'), q{host 'bar' does not do spidermonkey config});

    ok(!$bar->can('use_e4x'), q{host 'foo' does not know about e4x});
}

config_host_options: {
    my $host = RSP::Config->new({ config => $config })->host('foo');

    is($host->use_e4x, 1, q{Host Config use_e4x is inherited from the parent default});
    is($host->use_strict, 1, q{Host Config use_strict is inherited from the parent default});
    
    {
        local $config = clone($config);
        $config->{_}{spidermonkey_use_e4x} = 0;
        $config->{_}{spidermonkey_use_strict} = 0;
         
        $host = RSP::Config->new({ config => $config })->host('foo');
        is($host->use_e4x, 0, q{Host Config use_e4x is inherited from the parent (set)});
        is($host->use_strict, 0, q{Host Config use_strict is inherited from the parent (set)});
    }

    {
        local $config = clone($config);
        $config->{_}{spidermonkey_use_e4x} = 0;
        $config->{_}{spidermonkey_use_strict} = 0;
        $config->{'host:foo'}{use_e4x} = 1;
        $config->{'host:foo'}{use_strict} = 1;
         
        $host = RSP::Config->new({ config => $config })->host('foo');
        is($host->use_e4x, 1, q{Host Config use_e4x overrides the parent (true)});
        is($host->use_strict, 1, q{Host Config use_strict overrides the parent (true)});
    }

    {
        local $config = clone($config);
        $config->{_}{spidermonkey_use_e4x} = 1;
        $config->{_}{spidermonkey_use_strict} = 1;
        $config->{'host:foo'}{use_e4x} = 0;
        $config->{'host:foo'}{use_strict} = 0;
         
        $host = RSP::Config->new({ config => $config })->host('foo');
        is($host->use_e4x, 0, q{Host Config use_e4x overrides the parent (false)});
        is($host->use_strict, 0, q{Host Config use_strict overrides the parent (false)});
    }

    ok(!$host->can('arguments'));
    is(reftype($host->interrupt_handler), 'CODE', q{default interrupt_handler is correct});
    
}

