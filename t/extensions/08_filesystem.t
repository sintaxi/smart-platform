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
    use_ok('RSP::Extension::FileSystem');
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


my $root = $ji->config->root;
use File::Path qw(make_path);
make_path("$root/web");
open(my $web_fh, ">", "$root/web/foo.txt") or die "Could not open file: $!";
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

