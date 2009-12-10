#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(LWPx::ParanoidAgent t/Mock)];
use_ok('RSP::Extension::HTTP');

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
    my $http = RSP::Extension::HTTP->new({ js_instance => $ji });
    isa_ok($http, q{RSP::Extension::HTTP});

    my $provides = $http->provides;
    is_deeply($provides, [sort qw(http.request)], q{HTTP extension provides correct items});

    # XXX - temporary
    is($http->style, 'NG', q{Next-gen style extension});
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

method_for: {
    my $http = RSP::Extension::HTTP->new({ js_instance => $ji }); 
    
    my $method = $http->method_for('http.request');
    is($method, 'http_request', q{Correct method returned for function});

    throws_ok {
        $http->method_for('blargh');
    } qr{No method for function 'blargh'}, q{Non-existant function throws exception};
}

