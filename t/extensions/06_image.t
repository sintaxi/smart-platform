#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use mocked [qw(JavaScript t/Mock)];

use_ok('RSP::Extension::Image');

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
    my $image = RSP::Extension::Image->new({ js_instance => $ji });

    ok($image->does('RSP::Role::Extension'), q{Image does RSP::Role::Extension});
    ok($image->does('RSP::Role::Extension::JSInstanceManipulation'), q{Image does RSP::Role::Extension::JSInstanceManipulation});

    {
        $image->bind;

        ok($JavaScript::Context::BINDED_CLASSES->{'Image'}, q{Image had binded class});
        my $BIND = $JavaScript::Context::BINDED_CLASSES->{'Image'};
        is($BIND->{name}, 'Image', q{Bound class has correct name});
        is($BIND->{package}, 'RSP::JSObject::Image', q{Bound class is of correct package});

        is(reftype($BIND->{properties}{width}{getter}), 'CODE', q{Bound class has a 'width' property getter});
        is(reftype($BIND->{properties}{height}{getter}), 'CODE', q{Bound class has a 'height' property getter});
        
        is(reftype($BIND->{methods}{flip_horizontal}), 'CODE', q{Bound class has a 'flip_horizontal' method});
        is(reftype($BIND->{methods}{flip_vertical}), 'CODE', q{Bound class has a 'flip_vertical' method});
        is(reftype($BIND->{methods}{rotate}), 'CODE', q{Bound class has a 'rotate' method});
        is(reftype($BIND->{methods}{scale}), 'CODE', q{Bound class has a 'scale' method});
        is(reftype($BIND->{methods}{crop}), 'CODE', q{Bound class has a 'crop' method});
    }
}

