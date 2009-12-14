#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use mocked [qw(JavaScript t/Mock)];
use mocked [qw(Data::UUID::Base64URLSafe t/Mock)];

use_ok('RSP::Extension::UUID');

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
    my $uuid = RSP::Extension::UUID->new({ js_instance => $ji });

    ok($uuid->does('RSP::Role::Extension'), q{UUID does RSP::Role::Extension});
    ok($uuid->does('RSP::Role::Extension::JSInstanceManipulation'), q{UUID does RSP::Role::Extension::JSInstanceManipulation});

    {
        $uuid->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__uuid'}, q{UUID has binded extension}); 
        is(
            reftype($JavaScript::Context::BINDED->{'extensions.rsp__extension__uuid'}{uuid}), q{CODE}, 
            q{UUID has binded 'uuid' closure}
        ); 
    }
}

uuid: {
    my $uuid = RSP::Extension::UUID->new({ js_instance => $ji }); 
    is($uuid->uuid(), q{mmm... cookies on dowels}, q{uuid works as expected});
}

