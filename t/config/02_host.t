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

use mocked [qw(RSP::JS::Engine::TraceMonkey t/Mock)];

use RSP::Config;
#use_ok('RSP::Config::Host');

my $tmp_dir = tempdir();
my $tmp_dir2 = tempdir();
our $test_config = {
    '_' => {
        root => $tmp_dir,
        available_extensions => 'DataStore,Image,UUID',
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
        js_engine => 'TraceMonkey',
    },
    'host:bar' => {
    },
};



basic: {
    my $conf = RSP::Config->new(config => $test_config);
    isa_ok($conf, 'RSP::Config');
}

check_js_engine: {
    # XXX - NB: the TraceMonkey Engine is currently mocked in t/Mock
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->js_engine, 'TraceMonkey', q{js_engine is correct});

    local $test_config = clone($test_config);
    delete $test_config->{'host:foo'}{js_engine};
    $conf = RSP::Config->new(config => $test_config);
    $host = $conf->host('foo');
    is($host->js_engine, 'SpiderMonkey', q{js_engine is correct (default)});

    throws_ok {
        local $test_config = clone($test_config);
        $test_config->{'host:foo'}{js_engine} = 'ERPLE';
        $conf = RSP::Config->new(config => $test_config);
        $host = $conf->host('foo');
    } qr{Could not load class '.+?ERPLE' for JS Engine 'ERPLE': },
        q{Non-existing Javascript engine throws exception};
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
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->should_report_consumption, 0, 'report consumption is correct');
    
    $host = $conf->host('bar');
    is($host->should_report_consumption, 1, 'report consumption is correct (default: true)');
}

check_host_entrypoint: {
    my $conf = RSP::Config->new(config => $test_config)->host('foo');
    is($conf->entrypoint, 'main', 'entrypoint is correct');
}

check_host_extensions: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is_deeply($host->extensions, [qw(RSP::Extension::DataStore RSP::Extension::Image RSP::Extension::UUID)],
        'host extensions are correct');
    
    local $test_config = clone($test_config);
    delete $test_config->{'host:foo'}{extensions};
    $conf = RSP::Config->new(config => $test_config);
    $host = $conf->host('foo');
    is_deeply($host->extensions, [qw(RSP::Extension::DataStore)], q{no extensions gives blank list});

    local $test_config = clone($test_config);
    $test_config->{'host:foo'}{extensions} = 'flibble';
    $conf = RSP::Config->new(config => $test_config);
    $host = $conf->host('foo');
    throws_ok {
        $host->extensions
    } qr{Could not load extension 'RSP::Extension::flibble', was not supplied in available extensions list},
        q{Non-existant extension class throws exception};
}

check_hostname: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->hostname, 'foo', q{hostname is correct});
}

check_actual_host: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->actual_host, 'actuallyhere.com', 'Actual host returned');

    $host = $conf->host('bar');
    is($host->actual_host, 'bar', 'Actual host returned (without alternate)');
}

check_host_root: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->root, "$tmp_dir2/actuallyhere.com", 'root directory returned');

    chmod 0444, $tmp_dir2;
    $host = $conf->host('bar');
    throws_ok {
        $host->root
    } qr{Unable to create hostdirectory '\Q$tmp_dir2/bar\E'},
        q{Exception thrown when unable to create root};

    chmod 0777, $tmp_dir2;
    make_path("$tmp_dir2/bar");

    $host = $conf->host('bar');
    is($host->root, "$tmp_dir2/bar", q{root uses pre-existing directory});
}

check_code: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('bar');
    throws_ok {
        $host->code
    } qr{Code directory '\Q$tmp_dir2/bar/js\E' does not exist},
        q{Exception thrown when code path does not exist};

    make_path("$tmp_dir2/bar/js");
    $host = $conf->host('bar');
    is($host->code, "$tmp_dir2/bar/js", q{code uses pre-existing directory});

    # Create the code directory for host 'foo' so that the rest of the tests work
    make_path("$tmp_dir2/actuallyhere.com/js");
}

check_bootstrap: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->bootstrap_file, "$tmp_dir2/actuallyhere.com/js/bootstrap.js", 'bootstrap file path returned');
}

check_is_active: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->is_active, 1, q{Host foo is active});

    my $non_host_conf = $conf->host('flibble');
    is($non_host_conf->is_active, 0, q{Host flibble isn't active});
}

check_alloc_size: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->alloc_size, 8388608, q{Allocation size is correct});
}

check_log_directory: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->log_directory, "$tmp_dir2/actuallyhere.com/log", 'log directory returned');

    chmod 0444, "$tmp_dir2/bar";
    $host = $conf->host('bar');
    throws_ok {
        $host->log_directory
    } qr{Unable to create log directory '\Q$tmp_dir2/bar/log\E'},
        q{Exception thrown when unable to create code path};

    chmod 0777, "$tmp_dir2/bar";
    make_path("$tmp_dir2/bar/log");

    $host = $conf->host('bar');
    is($host->log_directory, "$tmp_dir2/bar/log", q{log directory uses pre-existing directory});

}

check_access_log: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');
    is($host->access_log, "$tmp_dir2/actuallyhere.com/log/access_log", q{access log is correct});
}

check_web: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('bar');
    throws_ok {
        $host->web
    } qr{Web directory '\Q$tmp_dir2/bar/web\E' does not exist},
        q{Exception thrown when code path does not exist};

    make_path("$tmp_dir2/bar/web");
    $host = $conf->host('bar');
    is($host->web, "$tmp_dir2/bar/web", q{code uses pre-existing directory});
}

check_file: {
    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('bar');

    is($host->file(code => 'some_code.js'), "$tmp_dir2/bar/js/some_code.js", q{file for type 'code' is correct});
    is($host->file(web => 'some_image.png'), "$tmp_dir2/bar/web/some_image.png", q{file for type 'web' is correct});

    throws_ok {
        $host->file(cookies_on_dowels => 'bleh');
    } qr{Unknown file type 'cookies_on_dowels'},
        q{Unknown file type throws exception};
}

#---------------------------------------------
# NEW STYLE
#---------------------------------------------

new_style_loading: {
    open(my $fh, ">", "$tmp_dir2/bar/prefs.json") or die "Could not open file: $!";
    print {$fh} "";
    close($fh);

    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('bar');
    ok($host->new_style, q{Host is new style});
    is($host->file(code => 'some_code.js'), "$tmp_dir2/bar/some_code.js", q{file for 'code' is correct, new style});
    is($host->file(web => 'some_code.js'), "$tmp_dir2/bar/some_code.js", q{file for 'web' is correct, new style});
    is($host->bootstrap_file, "$tmp_dir2/bar/bootstrap.js", 'bootstrap file path returned, new style');
}
