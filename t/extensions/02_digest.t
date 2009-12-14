#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use_ok('RSP::Extension::Digest');

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
    my $digest = RSP::Extension::Digest->new({ js_instance => $ji });

    ok($digest->does('RSP::Role::Extension'), q{Digest does RSP::Role::Extension});
    ok($digest->does('RSP::Role::Extension::JSInstanceManipulation'), q{Digest does RSP::Role::Extension::JSInstanceManipulation});

    {
        $digest->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__digest'}, q{Digest has binded extension});
    
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__digest'};
        is(reftype($BIND->{digest}), q{HASH}, q{Digest has binded 'digest' hash}); 
        is(reftype($BIND->{digest}{sha1}), q{HASH}, q{Digest has binded 'digest.sha1' hash}); 
        is(reftype($BIND->{digest}{sha1}{'hex'}), q{CODE}, q{Digest has binded 'digest.sha1.hex' hash}); 
        is(reftype($BIND->{digest}{sha1}{base64}), q{CODE}, q{Digest has binded 'digest.sha1.base64' hash}); 
        is(reftype($BIND->{digest}{md5}), q{HASH}, q{Digest has binded 'digest.md5' hash}); 
        is(reftype($BIND->{digest}{md5}{'hex'}), q{CODE}, q{Digest has binded 'digest.md5.hex' hash}); 
        is(reftype($BIND->{digest}{md5}{base64}), q{CODE}, q{Digest has binded 'digest.md5.base64' hash}); 
    }
}

digests: {
    my $digest = RSP::Extension::Digest->new({ js_instance => $ji }); 

    my $str = "foo";
    is($digest->digest_sha1_hex($str), Digest::SHA1::sha1_hex($str), q{SHA1 hex is correct});
    is($digest->digest_sha1_base64($str), Digest::SHA1::sha1_base64($str), q{SHA1 base64 is correct});
    is($digest->digest_md5_hex($str), Digest::MD5::md5_hex($str), q{MD5 hex is correct});
    is($digest->digest_md5_base64($str), Digest::MD5::md5_base64($str), q{MD5 base64 is correct});
    
}

{
    package Bleh;
    use Moose;
    has string => (is => 'ro', required => 1);
    sub as_string { my ($self) = @_; return $self->string; }
    no Moose;
}

digests_with_objects: {
    my $digest = RSP::Extension::Digest->new({ js_instance => $ji }); 

    my $str = 'foo';
    my $data = Bleh->new(string => $str);

    is($digest->digest_sha1_hex($data), Digest::SHA1::sha1_hex($str), q{SHA1 hex is correct (object)});
    is($digest->digest_sha1_base64($data), Digest::SHA1::sha1_base64($str), q{SHA1 base64 is correct (object)});
    is($digest->digest_md5_hex($data), Digest::MD5::md5_hex($str), q{MD5 hex is correct (object)});
    is($digest->digest_md5_base64($data), Digest::MD5::md5_base64($str), q{MD5 base64 is correct (object)});
}

