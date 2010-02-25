#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use mocked [qw(JavaScript t/Mock)];

use lib qw(t/lib);
use TestHelper qw(initialize_test_js_instance);

use Scalar::Util qw(reftype);
use File::Temp qw(tempdir);

my $tmp_dir = tempdir();

my ($ji, $conf) = initialize_test_js_instance({
    rsp => { storage => 'storage:local' },
    'localstorage' => { 
        datadir => $tmp_dir 
    },
    'storage:local' => {
        MediaStore => 'Local',
    },
});

basic: {
    use_ok('RSP::Extension::MediaStore');
    ok(RSP::Extension::MediaStore->does('RSP::Role::AppMutation'), q{MediaStore does RSP::Role::AppMutation});
    RSP::Extension::MediaStore->apply_mutations($conf);

    ok($ji->config->_master->does('RSP::Role::Config::MogileStorage'), q{Config now does MogileStorage});
    ok($ji->config->_master->does('RSP::Role::Config::LocalStorage'), q{Config now does LocalMediaStorage});
    ok($ji->config->_master->does('RSP::Role::Config::DataStorage'), q{Config now does DataStorage});
    ok($ji->config->does('RSP::Role::Config::DataStorage::Host'), q{Config now does DataStorage::Host});

    my $media = RSP::Extension::MediaStore->new({ js_instance => $ji });
    ok($media->does('RSP::Role::Extension'), q{MediaStore does RSP::Role::Extension});
    ok($media->does('RSP::Role::Extension::JSInstanceManipulation'), q{MediaStore does RSP::Role::Extension::JSInstanceManipulation});
}

local: {
    my $media = RSP::Extension::MediaStore->new({ js_instance => $ji });
    $media->bind;
    {
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__mediastore'}, q{MediaStore has binded extension});

        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__mediastore'};
        is(reftype($BIND->{mediastore}), q{HASH}, q{MediaStore has binded 'mediastore' hash}); 
        is(reftype($BIND->{mediastore}{get}), q{CODE}, q{MediaStore has binded 'mediastore.get' closure}); 
        is(reftype($BIND->{mediastore}{remove}), q{CODE}, q{MediaStore has binded 'mediastore.remove' closure}); 
        is(reftype($BIND->{mediastore}{'write'}), q{CODE}, q{MediaStore has binded 'mediastore.write' closure}); 
    }
    {
        ok($JavaScript::Context::BINDED_CLASSES->{'MediaFile'}, q{MediaStore had binded class});
        
        my $BIND = $JavaScript::Context::BINDED_CLASSES->{'MediaFile'};
        is($BIND->{name}, 'MediaFile', q{Bound class has correct name});
        is($BIND->{package}, 'RSP::JSObject::MediaFile::Local', q{Bound class is of correct package});

        is(reftype($BIND->{properties}{filename}{getter}), 'CODE', q{Bound class has a 'filename' property getter});
        is(reftype($BIND->{properties}{mimetype}{getter}), 'CODE', q{Bound class has a 'mimetype' property getter});
        is(reftype($BIND->{properties}{size}{getter}), 'CODE', q{Bound class has a 'size' property getter});
        is(reftype($BIND->{properties}{'length'}{getter}), 'CODE', q{Bound class has a 'length' property getter});
        is(reftype($BIND->{properties}{'digest'}{getter}), 'CODE', q{Bound class has a 'digest' property getter});

        is(reftype($BIND->{methods}{remove}), 'CODE', q{Bound class has a 'remove' method});
    }
}

mogile: {
    my ($ji, $conf) = initialize_test_js_instance({
        rsp => { storage => 'storage:mogile' },
        'mogilefs' => { 
            trackers => 'somehost:1234'
        },
        'storage:mogile' => {
            MediaStore => 'MogileFS',
        },
    });

    local $JavaScript::Context::BINDED;
    local $JavaScript::Context::BINDED_CLASSES;

    my $media = RSP::Extension::MediaStore->new({ js_instance => $ji });
    $media->bind;
    {
        ok($JavaScript::Context::BINDED->{'extensions.rsp__extension__mediastore'}, q{MediaStore has binded extension});

        my $BIND = $JavaScript::Context::BINDED->{'extensions.rsp__extension__mediastore'};
        is(reftype($BIND->{mediastore}), q{HASH}, q{MediaStore has binded 'mediastore' hash}); 
        is(reftype($BIND->{mediastore}{get}), q{CODE}, q{MediaStore has binded 'mediastore.get' closure}); 
        is(reftype($BIND->{mediastore}{remove}), q{CODE}, q{MediaStore has binded 'mediastore.remove' closure}); 
        is(reftype($BIND->{mediastore}{'write'}), q{CODE}, q{MediaStore has binded 'mediastore.write' closure}); 
    }
    {
        ok($JavaScript::Context::BINDED_CLASSES->{'MediaFile'}, q{MediaStore had binded class});
        
        my $BIND = $JavaScript::Context::BINDED_CLASSES->{'MediaFile'};
        is($BIND->{name}, 'MediaFile', q{Bound class has correct name});
        is($BIND->{package}, 'RSP::JSObject::MediaFile::Mogile', q{Bound class is of correct package});

        is(reftype($BIND->{properties}{filename}{getter}), 'CODE', q{Bound class has a 'filename' property getter});
        is(reftype($BIND->{properties}{mimetype}{getter}), 'CODE', q{Bound class has a 'mimetype' property getter});
        is(reftype($BIND->{properties}{size}{getter}), 'CODE', q{Bound class has a 'size' property getter});
        is(reftype($BIND->{properties}{'length'}{getter}), 'CODE', q{Bound class has a 'length' property getter});
        is(reftype($BIND->{properties}{'digest'}{getter}), 'CODE', q{Bound class has a 'digest' property getter});

        is(reftype($BIND->{methods}{remove}), 'CODE', q{Bound class has a 'remove' method});
    }
}


