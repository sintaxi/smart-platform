#!/usr/bin/perl

use strict;
use warnings;

use Test::More  $ENV{'MOGILEFS_TRACKERS'} ? 
    ('no_plan') 
    : (skip_all => 'MOGILEFS_TRACKERS must be set for this test');


use File::Temp qw(tempdir);
my $tmp_dir = tempdir();

basic: {
    use_ok('RSP::Mediastore::MogileFS');

    my $media = RSP::Mediastore::MogileFS->new(
        namespace => 'test.smart.joyent.com', 
        trackers => [$ENV{MOGILEFS_TRACKERS}]
    );
    isa_ok($media, 'RSP::Mediastore::MogileFS');

    my ($fname, $data) = ("foobar", "bazbashfoo");
    ok($media->write("test-data", $fname, $data), q{file written correctly});
    my $fobj = $media->get("test-data", $fname);
    ok($fobj, q{file retrieved correctly});
    isa_ok($fobj, q{RSP::JSObject::MediaFile::Mogile});

    ok($media->remove("test-data", $fname), q{file written correctly});
}

