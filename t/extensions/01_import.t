#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use mocked [qw(JavaScript t/Mock)];

use_ok('RSP::Extension::Import');

use File::Temp qw(tempfile tempdir);
use File::Path qw(make_path);
use Scalar::Util qw(reftype);

use RSP::Config;

my $tmp_dir = tempdir();
my $tmp_dir2 = tempdir();
my ($fh, $filename) = tempfile();

our $test_config = {
    '_' => {
        root => $tmp_dir,
    },
    rsp => {
        oplimit => 123_456,
        hostroot => $tmp_dir2,
    },
    'host:foo' => {
        noconsumption => 1,
        alternate => 'actuallyhere.com',
        bootstrap_file => $filename,
    },
    'host:bar' => {
    },
};

make_path("$tmp_dir2/actuallyhere.com/js");
open(my $boot_fh, ">", "$tmp_dir2/actuallyhere.com/js/bootstrap.js") or die "Could not open file: $!";
print {$boot_fh} <<EOJS;
var who = 'world';
function main () {
    return "Hello "+who;
}
EOJS
close($boot_fh);

my $conf = RSP::Config->new(config => $test_config);
my $host = $conf->host('foo');

use RSP::JS::Engine::SpiderMonkey;
my $je = RSP::JS::Engine::SpiderMonkey->new;
$je->initialize;
my $ji = $je->create_instance({ config => $host });
$ji->initialize;

open(my $js_fh, ">", "$tmp_dir2/actuallyhere.com/js/foo.js") or die "Could not open file: $!";
print {$js_fh} <<EOJS;
"howdy";
EOJS
close($js_fh);


basic: {
    my $import = RSP::Extension::Import->new({ js_instance => $ji });

    ok($import->does('RSP::Role::Extension'), q{Import does RSP::Role::Extension});
    ok($import->does('RSP::Role::Extension::JSInstanceManipulation'), q{Import does RSP::Role::Extension::JSInstanceManipulation});

    {
        $import->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__import'}, q{Import has binded extension}); 
        is(
            reftype($JavaScript::Context::BINDED->{'extensions.rsp__extension__import'}{use}), q{CODE}, 
            q{Import has binded 'use' closure}
        ); 
    }

}

use: {
    my $import = RSP::Extension::Import->new({ js_instance => $ji }); 

    lives_ok {
        $import->use('foo');
    } q{Import works};
    is($JavaScript::Context::FILE, "$tmp_dir2/actuallyhere.com/js/foo.js", q{Library import is correct});

    throws_ok {
        $import->use("meh");
    } qr{Library 'meh' does not exist$}, q{Non-existant library throws exception};

    $JavaScript::Context::EVAL_RESULT = 0;
    throws_ok {
        $import->use("foo");
    } qr{Unable to load library 'foo': \[mocked\] fail$},
        q{Failing library throws exception};
}

global_lib: {
    local $TODO = q{Wait until we have a clearer idea of how we want to achieve this};

    make_path("$tmp_dir/global_libraries/flibble/2_0");
    open(my $global_fh, ">", "$tmp_dir/global_libraries/flibble/2_0/flibble.js");
    print {$global_fh} "function blah(){ return 'howdy'; }\n";
    close $global_fh;
    my $import = RSP::Extension::Import->new({ js_instance => $ji }); 

    local $JavaScript::Context::FILE;
    lives_ok {
        $import->use("flibble", "2.0");
    } q{Able to use global library};
    is($JavaScript::Context::FILE, "$tmp_dir/global_libraries/flibble/2_0/flibble.js", q{Correct global library is used});

    throws_ok {
        $import->use("flibble", "3.0");
    } qr{Library name 'flibble' at version '3\.0' does not exist}, q{Non-existant version throws exception};

}

