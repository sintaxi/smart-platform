#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use Scalar::Util qw(reftype);
use File::Temp qw(tempfile tempdir);
use File::Path qw(make_path);

use RSP::Config;
use_ok('RSP::JS::Engine::SpiderMonkey');

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

basic: {
   my $je = RSP::JS::Engine::SpiderMonkey->new;
   $je->initialize;

   my $ji = $je->create_instance({ config => $host });
   $ji->initialize;
 
   my $response;
   lives_ok { 
        $response = $ji->run;
   } q{Spidermonkey runs correctly};
   is($response, "Hello world", q{Correct response returned});
}

