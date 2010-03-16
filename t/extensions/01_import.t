#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);


use Scalar::Util qw(reftype);

my ($ji, $conf) = initialize_test_js_instance({});
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

    local $JavaScript::Context::EVAL_RESULT = 0;
    throws_ok {
        $import->use("foo");
    } qr{Unable to load library 'foo': \[mocked\] fail$},
        q{Failing library throws exception};
}

secured: {
    my $import = RSP::Extension::Import->new({ js_instance => $ji }); 

    dies_ok {
        $import->use('\\../\\\../\\\\../\\\\\../\\\\\\../foo');
    } q{Import works};
}

globbing: {
    open(my $js_fh, ">", "$root/js/this_one.js") or die "Could not open file: $!";
    print {$js_fh} <<EOJS;
"howdy";
EOJS
    close($js_fh);

    open($js_fh, ">", "$root/js/this_otherone.js") or die "Could not open file: $!";
    print {$js_fh} <<EOJS;
"howdy";
EOJS
    close($js_fh);
    
    my $import = RSP::Extension::Import->new({ js_instance => $ji }); 

    local $JavaScript::Context::FILES;
    lives_ok {
        $import->use('this_*');
    } q{Import works};
    is_deeply($JavaScript::Context::FILES, ["$root/js/this_one.js", "$root/js/this_otherone.js"], q{Library globbing import is correct});

}
