#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use File::Spec;
use Cwd qw(getcwd);
use Carp qw( confess );

use_ok('RSP::Config');

my $tmp_dir = tempdir();
my $tmp_dir2 = tempdir();
our $test_config = {
    root => $tmp_dir,
    extensions => 'DataStore',
    oplimit => 123_456,
    hostroot => $tmp_dir2, 
    server => {
        Root => $tmp_dir,
        ConnectionTimeout => 123,
        MaxRequestsPerClient => 13,
        MaxRequestsPerChild => 23,
        User => 'zim',
        Group => 'aliens',
        MaxClients => 47,
    },
    'host:foo' => {
    },
    'host:bar' => {
    },
};

basic: {
    my $conf = RSP::Config->new(config => $test_config);
    isa_ok($conf, 'RSP::Config');
}

check_rsp_root_is_correct: {
    my $conf = RSP::Config->new(config => $test_config);
    is($conf->root, $tmp_dir, 'root directory is correct');

    local $test_config = { %$test_config };
    delete $test_config->{root};
    $conf = RSP::Config->new(config => $test_config);
    is($conf->root, getcwd(), 'root defaults to current working directory');

    local $test_config = { %$test_config, root => 'reallyreallyreallyshouldnotexsit' };
    $conf = RSP::Config->new(config => $test_config);
    throws_ok {
        $conf->root
    } qr/Directory '.+?' does not exist/, 'non existant root directory throws exception';
}

check_rsp_exceptions_are_correct: {
    my $conf = RSP::Config->new(config => $test_config);
    is_deeply( $conf->extensions, [qw(RSP::Extension::DataStore)], 'Extensions returned correctly');

    local $test_config = { %$test_config, extensions => 'ThisClassReallyShouldNotExist' };
    $conf = RSP::Config->new(config => $test_config);
    throws_ok {
        $conf->extensions
    } qr/Could not load extension 'RSP::Extension::ThisClassReallyShouldNotExist'/, 
        'Non-existing extension class throws error';
}

check_hostroot_is_correct: {
    my $conf = RSP::Config->new(config => $test_config);
    is($conf->hostroot, $tmp_dir2, 'hostroot directory for server is correct');
   
    local $test_config = { %$test_config };
    $test_config->{hostroot} = 'bob';
    mkpath("$tmp_dir/bob");

    $conf = RSP::Config->new(config => $test_config);
    is($conf->hostroot, "$tmp_dir/bob", 'hostroot directory is correct (relative)');

    TODO: {
        local $TODO = 'Needs implemented';
        local $test_config = { %$test_config };
        $test_config->{hostroot} = '../../../../bob';
        $conf = RSP::Config->new(config => $test_config);
        throws_ok {
            $conf->hostroot
        } qr/Hostroot relative paths must be under the RSP root/,
            q{Ensure we protect ourselves from odd or malicious paths};
    }
}

check_global_oplimit_is_correct: {
    my $conf = RSP::Config->new(config => $test_config);
    is($conf->oplimit, 123_456, 'oplimit is correct');

    local $test_config = { %$test_config };
    delete $test_config->{oplimit};
    $conf = RSP::Config->new(config => $test_config);
    is($conf->oplimit, 100_000, 'oplimit defaults to 100,000');
}

check_hosts_are_correct: {
    my $conf = RSP::Config->new(config => $test_config);
  
    my $hosts = $conf->_hosts;
    ok(exists $hosts->{foo} && exists $hosts->{bar}, "Hosts are gleaned correctly");

    my $host_conf = $conf->host('foo');
    isa_ok($host_conf, 'RSP::Config::Host');

    throws_ok {
        $conf->host('baz');
    } qr/No configuration supplied for 'baz'/,
        'Non-existing host throws error';
}

