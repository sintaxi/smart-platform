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

basic: {
    use_ok('RSP::Extension::Console');
    my $console = RSP::Extension::Console->new({ js_instance => $ji });

    ok($console->does('RSP::Role::Extension'), q{Console does RSP::Role::Extension});
    ok($console->does('RSP::Role::Extension::JSInstanceManipulation'), q{Console does RSP::Role::Extension::JSInstanceManipulation});

    {
        $console->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__console'}, q{Console has binded extension});
    
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__console'};
        is(reftype($BIND->{console}), q{HASH}, q{Console has binded 'console' hash}); 
        is(reftype($BIND->{console}{'log'}), q{CODE}, q{Digest has binded 'console.log' closure}); 
    }
}

console_log: {
    my $console = RSP::Extension::Console->new({ js_instance => $ji });

    my $str;
    use IO::String;
    my $io =  IO::String->new(\$str);
    local *STDERR = $io;
    $console->console_log("howdy");
    is($str, 'howdy', q{Console logging works});

    local $TODO = "THIS NEEDS TO WORK IN A DIFFERENT WAY!!!";
}



