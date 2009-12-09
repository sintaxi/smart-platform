
#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use_ok('RSP::Extension::Digest');

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
    isa_ok($digest, q{RSP::Extension::Digest});

    my $provides = $digest->provides;
    is_deeply($provides, [sort qw(digest.sha1.hex digest.sha1.base64 digest.md5.hex digest.md5.base64)], q{iDigest extension provides correct items});

    # XXX - temporary
    is($digest->style, 'NG', q{Next-gen style extension});
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

method_for: {
    my $digest = RSP::Extension::Digest->new({ js_instance => $ji }); 
    
    my $method = $digest->method_for('digest.sha1.hex');
    is($method, 'digest_sha1_hex', q{Correct method returned for function});

    throws_ok {
        $digest->method_for('blargh');
    } qr{No method for function 'blargh'}, q{Non-existant function throws exception};
}

