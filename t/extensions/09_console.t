#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use_ok('RSP::Extension::Console');

use Scalar::Util qw(reftype);
use RSP::Config;

use File::Path qw(make_path);
use File::Temp qw(tempdir tempfile);
my $tmp_dir = tempdir();
my $tmp_dir2 = tempdir();

make_path("$tmp_dir2/actuallyhere.com/js");
open(my $fh, ">", "$tmp_dir2/actuallyhere.com/js/bootstrap.js");
print {$fh} "function main() { return 'hello world'; }";
close $fh;

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
        #bootstrap_file => $filename,
    },
    'host:bar' => {
    },
};

my $conf = RSP::Config->new(config => $test_config);
my $host = $conf->host('foo');

use RSP::JS::Engine::SpiderMonkey;
my $je = RSP::JS::Engine::SpiderMonkey->new;
$je->initialize;
my $ji = $je->create_instance({ config => $host });
$ji->initialize;

basic: {
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



