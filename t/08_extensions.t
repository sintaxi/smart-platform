#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use RSP::Config;

use_ok("RSP::JS::Engine::SpiderMonkey");

{
    package RSP::Extension::Example;

    use Moose;
    with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

    sub bind {
        my ($self) = @_;
        $self->bind_extension({
            hello => $self->generate_js_closure('hello'),
            hello_who => $self->generate_js_closure('hello_who'),
            hello_but_dead => $self->generate_js_closure('hello_but_dead'),
        });
    }

    sub hello_but_dead {
        die "devil\n";
    }

    sub hello { 
        "world"; 
    }

    sub hello_who {
        my ($self, $who) = @_;
        return "hello $who";
    }

    no Moose;
    1;
}

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
        extensions => 'Example',
        #bootstrap_file => $filename,
    },
    'host:bar' => {
    },
};

my $conf = RSP::Config->new(config => $test_config);
my $host = $conf->host('foo');

my $je = RSP::JS::Engine::SpiderMonkey->new;
$je->initialize;
my $ji = $je->create_instance({ config => $host });
$ji->initialize;

basic: {
    is($ji->eval("system.hello()"), q{world}, q{Extension has been loaded});
    is($ji->eval("system.hello_who('bob')"), q{hello bob}, q{Extension has been loaded (and passes args)});
   
    $ji->eval("system.hello_but_dead();");
    like($@, qr{RSP::Extension::Example threw a binding error: devil$}, 
        q{Extension function throws correct exception});
}

