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
}

__END__
#use_ok('RSP::Config::Host');

my $tmp_dir = tempdir();
my $tmp_dir2 = tempdir();
our $test_config = {
    '_' => {
        root => $tmp_dir,
        extensions => 'DataStore',
    },
    rsp => {
        oplimit => 123_456,
        hostroot => $tmp_dir2,
    },
    'host:foo' => {
        oplimit => 654_321,
        noconsumption => 1,
        extensions => 'Image,UUID',
        alternate => 'actuallyhere.com',
    },
    'host:bar' => {
    },
};

basic: {
    my $conf = RSP::Config->new(config => $test_config);
    isa_ok($conf, 'RSP::Config');
}

check_host_oplimit_is_correct: {
    my $conf = RSP::Config->new(config => $test_config);

    my $host_conf = $conf->host('foo');
    is($host_conf->oplimit, 654_321, 'host oplimit correct');
    
    $host_conf = $conf->host('bar');
    is($host_conf->oplimit, 123_456, 'host oplimit correct (using parent config)');
    
    $host_conf = $conf->host('bar');
    is($host_conf->op_threshold, 123_456, 'host oplimit correct (using alias)');}

check_host_should_report_consumption: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->should_report_consumption, 0, 'report consumption is correct');
    
    $conf = RSP::Config->new(config => $test_config)->host('bar');
    is($conf->should_report_consumption, 1, 'report consumption is correct (default: true)');
}

check_host_entrypoint: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->entrypoint, 'main', 'entrypoint is correct');
}

check_host_extensions: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is_deeply($conf->extensions, [qw(RSP::Extension::DataStore RSP::Extension::Image RSP::Extension::UUID)],
        'host extensions are correct');
    
    local $test_config = clone($test_config);
    delete $test_config->{'host:foo'}{extensions};
    $conf = RSP::Config->new(config => $test_config)->host('foo');
    is_deeply($conf->extensions, [qw(RSP::Extension::DataStore)], q{no extensions gives blank list});

    local $test_config = clone($test_config);
    $test_config->{'host:foo'}{extensions} = 'flibble';
    $conf = RSP::Config->new(config => $test_config)->host('foo');
    throws_ok {
        $conf->extensions
    } qr{Could not load extension 'RSP::Extension::flibble':},
        q{Non-existant extension class throws exception};
}

check_hostname: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->hostname, 'foo', q{hostname is correct});
}

check_actual_host: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->actual_host, 'actuallyhere.com', 'Actual host returned');

    $conf = RSP::Config->new(config => $test_config)->host('bar');
    is($conf->actual_host, 'bar', 'Actual host returned (without alternate)');
}

check_host_root: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->root, "$tmp_dir2/actuallyhere.com", 'root directory returned');

    chmod 0444, $tmp_dir2;
    $conf = RSP::Config->new(config => $test_config)->host('bar');
    throws_ok {
        $conf->root
    } qr{Unable to create hostdirectory '\Q$tmp_dir2/bar\E'},
        q{Exception thrown when unable to create root};

    chmod 0777, $tmp_dir2;
    make_path("$tmp_dir2/bar");

    $conf = RSP::Config->new(config => $test_config)->host('bar');
    is($conf->root, "$tmp_dir2/bar", q{root uses pre-existing directory});
}

check_code: {
    my $conf = RSP::Config->new(config => $test_config)->host('bar');
    throws_ok {
        $conf->code
    } qr{Code directory '\Q$tmp_dir2/bar/js\E' does not exist},
        q{Exception thrown when code path does not exist};

    make_path("$tmp_dir2/bar/js");
    $conf = RSP::Config->new(config => $test_config)->host('bar');
    is($conf->code, "$tmp_dir2/bar/js", q{code uses pre-existing directory});

    # Create the code directory for host 'foo' so that the rest of the tests work
    make_path("$tmp_dir2/actuallyhere.com/js");
}

check_bootstrap: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->bootstrap_file, "$tmp_dir2/actuallyhere.com/js/bootstrap.js", 'bootstrap file path returned');
}

check_alloc_size: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->alloc_size, 2097152, q{Allocation size is correct});
}

check_log_directory: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->log_directory, "$tmp_dir2/actuallyhere.com/log", 'log directory returned');

    chmod 0444, "$tmp_dir2/bar";
    $conf = RSP::Config->new(config => $test_config)->host('bar');
    throws_ok {
        $conf->log_directory
    } qr{Unable to create log directory '\Q$tmp_dir2/bar/log\E'},
        q{Exception thrown when unable to create code path};

    chmod 0777, "$tmp_dir2/bar";
    make_path("$tmp_dir2/bar/log");

    $conf = RSP::Config->new(config => $test_config)->host('bar');
    is($conf->log_directory, "$tmp_dir2/bar/log", q{log directory uses pre-existing directory});

}

check_access_log: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->access_log, "$tmp_dir2/actuallyhere.com/log/access_log", q{access log is correct});
}

check_web: {
    my $conf = RSP::Config->new(config => $test_config)->host('bar');
    throws_ok {
        $conf->web
    } qr{Web directory '\Q$tmp_dir2/bar/web\E' does not exist},
        q{Exception thrown when code path does not exist};

    make_path("$tmp_dir2/bar/web");
    $conf = RSP::Config->new(config => $test_config)->host('bar');
    is($conf->web, "$tmp_dir2/bar/web", q{code uses pre-existing directory});
}

check_file: {
    my $conf = RSP::Config->new(config => $test_config)->host('bar');

    is($conf->file(code => 'some_code.js'), "$tmp_dir2/bar/js/some_code.js", q{file for type 'code' is correct});
    is($conf->file(web => 'some_image.png'), "$tmp_dir2/bar/web/some_image.png", q{file for type 'web' is correct});

    throws_ok {
        $conf->file(cookies_on_dowels => 'bleh');
    } qr{Unknown file type 'cookies_on_dowels'},
        q{Unknown file type throws exception};
}
