#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use mocked [qw(JavaScript t/Mock)];

use_ok('RSP::Extension::FileSystem');

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
    my $file = RSP::Extension::FileSystem->new({ js_instance => $ji });

    ok($file->does('RSP::Role::Extension'), q{File does RSP::Role::Extension});
    ok($file->does('RSP::Role::Extension::JSInstanceManipulation'), q{File does RSP::Role::Extension::JSInstanceManipulation});

    {
        $file->bind;

        ok($JavaScript::Context::BINDED_CLASSES->{'File'}, q{File had binded class});
        my $BIND = $JavaScript::Context::BINDED_CLASSES->{'File'};
        is($BIND->{name}, 'File', q{Bound class has correct name});
        is($BIND->{package}, 'RSP::JSObject::File', q{Bound class is of correct package});
        
        is(reftype($BIND->{properties}{contents}{getter}), 'CODE', q{Bound class has a 'contents' property getter});
        is(reftype($BIND->{properties}{filename}{getter}), 'CODE', q{Bound class has a 'filename' property getter});
        is(reftype($BIND->{properties}{mimetype}{getter}), 'CODE', q{Bound class has a 'mimetype' property getter});
        is(reftype($BIND->{properties}{size}{getter}), 'CODE', q{Bound class has a 'size' property getter});
        is(reftype($BIND->{properties}{'length'}{getter}), 'CODE', q{Bound class has a 'length' property getter});
        is(reftype($BIND->{properties}{mtime}{getter}), 'CODE', q{Bound class has a 'mtime' property getter});
        is(reftype($BIND->{properties}{'exists'}{getter}), 'CODE', q{Bound class has a 'exists' property getter});

        is(reftype($BIND->{methods}{toString}), 'CODE', q{Bound class has a 'toString' method});
       
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__filesystem'}, q{FileSystem has binded extension});
        my $BINDED = $JavaScript::Context::BINDED->{'extensions.rsp__extension__filesystem'};
        is(reftype($BINDED->{filesystem}), q{HASH}, q{FileSystem has binded 'filesystem' hash});
        is(reftype($BINDED->{filesystem}{get}), q{CODE}, q{FileSystem has binded 'filesystem.get' closure});
    }
}

make_path("$tmp_dir2/actuallyhere.com/web");
open(my $web_fh, ">", "$tmp_dir2/actuallyhere.com/web/foo.txt") or die "Could not open file: $!";
print {$web_fh} <<EOJS;
howdy
EOJS
close($web_fh);

get_file: {
    my $file = RSP::Extension::FileSystem->new({ js_instance => $ji });
    
    my $f = $file->get_file('foo.txt');
    ok($f, q{get_file returns an RSP::JSObject::File object});
    isa_ok($f, 'RSP::JSObject::File');

    throws_ok {
        $file->get_file('bob');
    } qr{couldn't open file bob: [^\n]+$}, q{non-existant file throws exception};
}

