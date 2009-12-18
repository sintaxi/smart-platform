#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use mocked [qw(LWPx::ParanoidAgent t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);

my $ji = initialize_test_js_instance({});

basic: {
    use_ok('RSP::Extension::HTTP');
    
    my $http = RSP::Extension::HTTP->new({ js_instance => $ji });

    ok($http->does('RSP::Role::Extension'), q{HTTP does RSP::Role::Extension});
    ok($http->does('RSP::Role::Extension::JSInstanceManipulation'), q{HTTP does RSP::Role::Extension::JSInstanceManipulation});

    {
        $http->bind;

        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__http'}, q{HTTP has binded extension});
        
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__http'};
        is(reftype($BIND->{http}), q{HASH}, q{HTTP has binded 'http' hash});
        is(reftype($BIND->{http}{request}), q{CODE}, q{HTTP has binded 'http.request' closure});
    }
}

http_request: {
    my $http = RSP::Extension::HTTP->new({ js_instance => $ji });

    local $LWPx::ParanoidAgent::RESPONSE = [200, 'OK', undef, "howdy"];
    my $response = $http->http_request(GET => 'http://foo.bar/');

    is($LWPx::ParanoidAgent::AGENT_STRING, 'Joyent Smart Platform / HTTP / 1.00', q{Agent string is correct});
    is($LWPx::ParanoidAgent::TIMEOUT, 10, q{Timeout is correct});

    is($LWPx::ParanoidAgent::REQUEST->uri, 'http://foo.bar/', q{Request URI is correct});
    is($LWPx::ParanoidAgent::REQUEST->method, 'GET', q{Request Method is correct});
    is_deeply($response, { code => 200, content => 'howdy', headers => {} }, q{Response is as expected});
}

