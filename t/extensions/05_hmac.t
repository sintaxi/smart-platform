#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use_ok('RSP::Extension::HMAC');

use Scalar::Util qw(reftype);
use RSP::Config;
use Digest::SHA1;
use Digest::MD5;

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
    my $hmac = RSP::Extension::HMAC->new({ js_instance => $ji });

    ok($hmac->does('RSP::Role::Extension'), q{HMAC does RSP::Role::Extension});
    ok($hmac->does('RSP::Role::Extension::JSInstanceManipulation'), q{HMAC does RSP::Role::Extension::JSInstanceManipulation});

    {
        $hmac->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__hmac'}, q{HMAC has binded extension});
    
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__hmac'};
        is(reftype($BIND->{digest}), q{HASH}, q{HMAC has binded 'digest' hash}); 
        is(reftype($BIND->{digest}{hmac}), q{HASH}, q{HMAC has binded 'digest.hmac' hash}); 
        is(reftype($BIND->{digest}{hmac}{sha1}), q{HASH}, q{HMAC has binded 'digest.hmac.sha1' hash}); 
        is(reftype($BIND->{digest}{hmac}{sha1}{'hex'}), q{CODE}, q{HMAC has binded 'digest.hmac.sha1.hex' hash}); 
        is(reftype($BIND->{digest}{hmac}{sha1}{base64}), q{CODE}, q{HMAC has binded 'digest.hmac.sha1.base64' hash}); 
    }
}

digests: {
    my $hmac = RSP::Extension::HMAC->new({ js_instance => $ji });

    use Digest::HMAC_SHA1;
    my $str = "foo";
    my $key = "bar";
    {
        my $dig = Digest::HMAC_SHA1->new($key);
        $dig->add($str);
        is($hmac->hmac_hex($str, $key), Digest::HMAC_SHA1::hmac_sha1_hex($str, $key), q{HMAC hex is correct});
        is($hmac->hmac_base64($str, $key), $dig->b64digest, q{HMAC base64 is correct});
    }
}

{
    package Bleh;
    use Moose;
    has string => (is => 'ro', required => 1);
    sub as_string { my ($self) = @_; return $self->string; }
    no Moose;
}

digests_with_objects: {
    my $hmac = RSP::Extension::HMAC->new({ js_instance => $ji }); 

    my $str = 'foo';
    my $data = Bleh->new(string => $str);
    my $key = "bar";

    {
        my $dig = Digest::HMAC_SHA1->new($key);
        $dig->add($str);
        is($hmac->hmac_hex($data, $key), Digest::HMAC_SHA1::hmac_sha1_hex($str, $key), q{HMAC hex is correct (object)});
        is($hmac->hmac_base64($data, $key), $dig->b64digest, q{HMAC base64 is correct (object)});
    }
}

