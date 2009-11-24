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
our $test_config = {
    root => $tmp_dir,
    extensions => 'DataStore',
    server => {
        Root => $tmp_dir,
        ConnectionTimeout => 123,
        MaxRequestsPerClient => 13,
        MaxRequestsPerChild => 23,
        User => 'zim',
        Group => 'aliens',
        MaxClients => 47,
    },
};

basic: {
    my $conf = RSP::Config->new(config => $test_config);
    isa_ok($conf, 'RSP::Config');
}

check_rsp_root_is_correct: {
    my $conf = RSP::Config->new(config => $test_config);
    is($conf->root, $tmp_dir, 'root directory is correct');

    local $test_config = $test_config;
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

check_server_root_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    isa_ok($server, 'RSP::Config::Server');
    is($server->root, $tmp_dir, 'root directory for server is correct');
}


check_server_pidfile_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    my $tmp_run_dir = File::Spec->catfile($tmp_dir, qw(run));

    throws_ok {
        $server->pidfile
    } qr/Could not locate run directory '\Q$tmp_run_dir\E' for pidfile/, 'non existant run directory throws error';

    mkpath($tmp_run_dir);
    is($server->pidfile, File::Spec->catfile($tmp_run_dir, qw(rsp.pid)), 'pidfile returned correctly');
}

check_server_connectiontimeout_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    is($server->connection_timeout, 123, 'connection timeout is correct');

    local $test_config = $test_config;
    delete $test_config->{server}{ConnectionTimeout};
    $server = RSP::Config->new(config => $test_config)->server;
    is($server->connection_timeout, 120, 'connection timeout defaults to 120');

}

check_server_maxrequests_perclient_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    is($server->max_requests_per_client, 13, 'max requests is correct');

    local $test_config = $test_config;
    delete $test_config->{server}{MaxRequestsPerClient};
    $server = RSP::Config->new(config => $test_config)->server;
    is($server->max_requests_per_client, 5, 'max requests defaults to 5');

}

check_server_user_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    is($server->user, 'zim', 'user for server is correct');

    local $test_config = $test_config;
    delete $test_config->{server}{User};
    $server = RSP::Config->new(config => $test_config)->server;
    is($server->user, undef, 'user for server is optional');
}

check_server_group_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    is($server->group, 'aliens', 'group for server is correct');

    local $test_config = $test_config;
    delete $test_config->{server}{Group};
    $server = RSP::Config->new(config => $test_config)->server;
    is($server->group, undef, 'group for server is optional');
}

check_server_maxchildren_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    is($server->max_children, 47, 'max children is correct');

    local $test_config = $test_config;
    delete $test_config->{server}{MaxClients};
    $server = RSP::Config->new(config => $test_config)->server;
    is($server->max_children, 5, 'max children defaults to 5');

}

check_server_maxrequests_perchild_is_correct: {
    my $server = RSP::Config->new(config => $test_config)->server;
    is($server->max_requests_per_child, 23, 'max requests per child is correct');

    local $test_config = $test_config;
    delete $test_config->{server}{MaxRequestsPerChild};
    $server = RSP::Config->new(config => $test_config)->server;
    # XXX - What should the default be?
    is($server->max_requests_per_child, 5, 'max requests per child defaults to 5');
}


