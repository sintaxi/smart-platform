#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use mocked [qw(Email::Send t/Mock)];
use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);

my $ji = initialize_test_js_instance({});

basic: {
    use_ok('RSP::Extension::SendMail');
    my $sendmail = RSP::Extension::SendMail->new({ js_instance => $ji });

    ok($sendmail->does('RSP::Role::Extension'), q{SendMail does RSP::Role::Extension});
    ok($sendmail->does('RSP::Role::Extension::JSInstanceManipulation'), q{SendMail does RSP::Role::Extension::JSInstanceManipulation});

    {
        $sendmail->bind;
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__sendmail'}, q{SendMail has binded extension});
    
        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__sendmail'};
        is(reftype($BIND->{email}), q{HASH}, q{SendMail has binded 'email' hash}); 
        is(reftype($BIND->{email}{'send'}), q{CODE}, q{SendMail has binded 'email.send' closure}); 
    }
}

email_send: {
    my $sendmail = RSP::Extension::SendMail->new({ js_instance => $ji }); 

    local $Email::Send::LAST_SENT;
    $sendmail->email_send({ To => 'foo@bar.com', From => 'bar@foo.com', Subject => 'Howdy' }, "Why hello there");
    is_deeply($Email::Send::LAST_SENT, {
        to => 'foo@bar.com', from => 'bar@foo.com', subject => 'Howdy', host => 'localhost',
        body => 'Why hello there',
    }, q{Email sent correctly});

    local $SIG{__DIE__};
    throws_ok {
        $sendmail->email_send({ From => 'bar@foo.com', Subject => 'Howdy' }, "Why hello there");
    } qr{^no 'To' header$}, q{To address required};
    throws_ok {
        $sendmail->email_send({ To => 'bar@foo.com', Subject => 'Howdy' }, "Why hello there");
    } qr{^no 'From' header$}, q{From address required};
    throws_ok {
        $sendmail->email_send({ To => 'foo@bar.com', From => 'bar@foo.com' }, "Why hello there");
    } qr{^no 'Subject' header$}, q{Subject required};
    throws_ok {
        $sendmail->email_send({ To => 'foo@bar.com', From => 'bar@foo.com', Subject => 'Howdy' });
    } qr{^no body$}, q{Body required};
}

