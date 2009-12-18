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
    use_ok('RSP::Extension::Digest');
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

