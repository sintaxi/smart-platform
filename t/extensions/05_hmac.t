#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);
use Digest::SHA1;
use Digest::MD5;

my $ji = initialize_test_js_instance({});

basic: {
    use_ok('RSP::Extension::HMAC');
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

