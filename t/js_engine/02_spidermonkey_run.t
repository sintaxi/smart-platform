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

my ($tmp_dir, $tmp_dir2) = (tempdir(), tempdir());
my ($fh, $filename) = tempfile();

our $test_config = {
    '_' => { root => $tmp_dir, },
    rsp => { hostroot => $tmp_dir2, },
    'host:foo' => { alternate => 'actuallyhere.com', bootstrap_file => $filename, },
};

my $conf = RSP::Config->new(config => $test_config);
my $host = $conf->host('foo');
my $root = $host->root;

make_path("$root/js");

open(my $boot_fh, ">", "$root/js/bootstrap.js") or die "Could not open file: $!";
print {$boot_fh} <<EOJS;
var who = 'world';
function main () {
    return "Hello "+who;
}
EOJS
close($boot_fh);

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

