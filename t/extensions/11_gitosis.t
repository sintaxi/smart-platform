#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(JavaScript t/Mock)];
use mocked [qw(Net::RabbitMQ t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use JSON::XS;
use Scalar::Util qw(reftype);

my ($ji, $conf) = initialize_test_js_instance({
    amqp => {
        user => 'test', pass => 'test', repository_management_exchange => 'gitosis_rsp_test', host => 'bob',
        repository_deletion_exchange => 'gitosis_rsp_delete_test',
        repository_key_registration_exchange => 'smart.gitosis.key.register',
    }    
});

basic: {
    use_ok('RSP::Extension::Gitosis');
    RSP::Extension::Gitosis->apply_mutations($ji->config->_master);
    my $gitosis = RSP::Extension::Gitosis->new({ js_instance => $ji });

    ok($gitosis->does('RSP::Role::Extension'), q{Gitosis does RSP::Role::Extension});
    ok($gitosis->does('RSP::Role::Extension::JSInstanceManipulation'), q{Gitosis does RSP::Role::Extension::JSInstanceManipulation});

    {
        $gitosis->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__gitosis'}, q{Gitosis has binded extension});
    
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__gitosis'};
        is(reftype($BIND->{gitosis}), q{HASH}, q{Gitosis has binded 'gitosis' hash}); 
        is(reftype($BIND->{gitosis}{repo}), q{HASH}, q{Gitosis has binded 'gitosis.repo' hash}); 
        is(reftype($BIND->{gitosis}{repo}{clone}), q{CODE}, q{Gitosis has binded 'gitosis.repo.clone' closure}); 
        is(reftype($BIND->{gitosis}{repo}{'delete'}), q{CODE}, q{Gitosis has binded 'gitosis.repo.delete' closure}); 
        is(reftype($BIND->{gitosis}{key}), q{HASH}, q{Gitosis has binded 'gitosis.key' hash}); 
        is(reftype($BIND->{gitosis}{key}{'write'}), q{CODE}, q{Gitosis has binded 'gitosis.key.write' closure}); 
        is(reftype($BIND->{gitosis}{key}{'exists'}), q{CODE}, q{Gitosis has binded 'gitosis.key.exists' closure}); 
    }
}

clone: {
    my $gitosis = RSP::Extension::Gitosis->new({ js_instance => $ji }); 

    local $Net::RabbitMQ::PUBLISHED;
    $gitosis->clone("from here", "to here");
    is_deeply($Net::RabbitMQ::PUBLISHED, {
        channel => 1, route_key => 'gitosis_rsp_test', 
        msg => encode_json({ from_project => 'from here', to_project => 'to here' }),
        exchange => 'gitosis_rsp_test',
    }, q{Gitosis repo clone() published to AMQP correctly});
}

delete_repo: {
    my $gitosis = RSP::Extension::Gitosis->new({ js_instance => $ji }); 

    local $Net::RabbitMQ::PUBLISHED;
    $gitosis->delete_repo("some.host.somewhere");
    is_deeply($Net::RabbitMQ::PUBLISHED, {
        channel => 1, route_key => 'gitosis_rsp_delete_test', 
        msg => encode_json({ repo => 'some.host.somewhere' }),
        exchange => 'gitosis_rsp_delete_test',
    }, q{Gitosis repo delete() published to AMQP correctly});
}

clone: {
    my $gitosis = RSP::Extension::Gitosis->new({ js_instance => $ji }); 

    local $Net::RabbitMQ::PUBLISHED;
    $gitosis->write_key("bob", "thingthingthing");
    is_deeply($Net::RabbitMQ::PUBLISHED, {
        channel => 1, route_key => 'smart.gitosis.key.register', 
        msg => encode_json({ user => 'bob', key => 'thingthingthing' }),
        exchange => 'smart.gitosis.key.register',
    }, q{Gitosis repo key.write() published to AMQP correctly});
}

