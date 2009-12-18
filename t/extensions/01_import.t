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
my $root = $ji->config->root;

open(my $js_fh, ">", "$root/js/foo.js") or die "Could not open file: $!";
print {$js_fh} <<EOJS;
"howdy";
EOJS
close($js_fh);


basic: {
    use_ok('RSP::Extension::Import');
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
    is($JavaScript::Context::FILE, "$root/js/foo.js", q{Library import is correct});

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

    my $tmp_dir = "/tmp";
    use File::Path qw(make_path);
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

