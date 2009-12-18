#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use_ok('RSP::Extension::JSONEncoder');

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
    my $jsonenc = RSP::Extension::JSONEncoder->new({ js_instance => $ji });

    ok($jsonenc->does('RSP::Role::Extension'), q{JSONEncoder does RSP::Role::Extension});
    ok($jsonenc->does('RSP::Role::Extension::JSInstanceManipulation'), q{JSONEncoder does RSP::Role::Extension::JSInstanceManipulation});

    {
        $jsonenc->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__jsonencoder'}, q{JSONEncoder has binded extension});
    
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__jsonencoder'};
        is(reftype($BIND->{json}), q{HASH}, q{JSONEncoder has binded 'json' hash}); 
        is(reftype($BIND->{json}{encode}), q{CODE}, q{JSONEncoder has binded 'json.encode' closure}); 
        is(reftype($BIND->{json}{decode}), q{CODE}, q{JSONEncoder has binded 'json.decode' closure}); 
    }
}

encode: {
    my $jsonenc = RSP::Extension::JSONEncoder->new({ js_instance => $ji });

    my $data = { foo => 'bar' }; 
    is($jsonenc->json_encode($data, 0), JSON::XS->new->utf8->encode($data), q{json_encode works correctly});
    is($jsonenc->json_encode($data, 1), JSON::XS->new->utf8->pretty->encode($data), q{json_encode works correctly (pretty)});

    {
        local $TODO = q{Since JSON::XS throws errors from XS space, we can't bypass the caller info};
        $data = bless({}, 'Foo');
        throws_ok {
            local $SIG{__DIE__};
            $jsonenc->json_encode($data, 0);
        } qr{encountered object '.+?', but neither allow_blessed nor convert_blessed settings are enabled$}, q{Error in encoding throws exception};
    }
}

decode: {
    my $jsonenc = RSP::Extension::JSONEncoder->new({ js_instance => $ji });

    my $data = q|{ "foo": "bar" }|;
    is_deeply($jsonenc->json_decode($data, 0), JSON::XS->new->utf8->decode($data), q{json_decode works correctly});
    is_deeply($jsonenc->json_decode($data, 1), JSON::XS->new->utf8->pretty->decode($data), q{json_decode works correctly (pretty)});

    {
        local $TODO = q{Since JSON::XS throws errors from XS space, we can't bypass the caller info (decode)};
        $data = '{ foo: ba }';
        throws_ok {
            local $SIG{__DIE__};
            $jsonenc->json_decode($data, 0);
        } qr|\Q'"' expected, at character offset 2 (before "foo: ba }")\E$|, q{Error in decoding throws exception};
    }
}

