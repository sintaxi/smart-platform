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

{
    package RSP::SimpleObj;

    use Moose;
    has simple_string => (is => 'rw');

    sub constructor {
        my ($class, $simple_string) = @_;
        return $class->new({ simple_string => $simple_string });
    }

    sub hello_string {
        my ($self, $who) = @_;
        return $self->simple_string . " $who";
    }

    sub hello_string_with_death {
        my ($self, $who) = @_;
        die "ERPLE\n";
    }

    no Moose;
    1;
}
{
    package RSP::Extension::ClassExample;
    
    use Moose;
    with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

    sub bind {
        my ($self) = @_;
        
        my $opts = {
            name => 'Example',
            'package' => 'RSP::SimpleObj',
            properties => {
                property_simple => { 
                    getter => $self->generate_js_method_closure('simple_string'),
                    setter => $self->generate_js_method_closure('simple_string'),
                },
            },
            methods => {
                simple_string => $self->generate_js_method_closure('hello_string'),
                simple_string_with_death => $self->generate_js_method_closure('hello_string_with_death'),
            },
            constructor => $self->generate_js_method_closure('constructor'),
        };
        
        $self->js_instance->bind_class(%$opts);
    }
    no Moose;
    1;
}

$test_config = {
    '_' => {
        root => $tmp_dir,
    },
    rsp => {
        hostroot => $tmp_dir2,
    },
    'host:foo' => {
        alternate => 'actuallyhere.com',
        extensions => 'ClassExample',
        #bootstrap_file => $filename,
    },
};

$conf = RSP::Config->new(config => $test_config);
$host = $conf->host('foo');

$je = RSP::JS::Engine::SpiderMonkey->new;
$je->initialize;
$ji = $je->create_instance({ config => $host });
$ji->initialize;

basic_class: {
    $ji->eval("
        var example_obj = new Example('Why howdy');    
    ");
    is($ji->eval("example_obj.property_simple"), q{Why howdy}, q{Property is correctly fetched});
    
    $ji->eval("example_obj.property_simple = 'Guten tag'");
    is($ji->eval("example_obj.property_simple"), q{Guten tag}, q{Property is correctly set});

    is($ji->eval("example_obj.simple_string('bob')"), q{Guten tag bob}, q{Method with arguments works correctly});

    $ji->eval("example_obj.simple_string_with_death();");
    like($@, qr{RSP::Extension::ClassExample threw a binding error: ERPLE$}, 
        q{Extension object method throws correct exception});
}

