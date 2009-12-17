#!/usr/bin/env perl

use strict;
use warnings;

use mocked [qw(Imager t/Mock)];
use Test::More qw(no_plan);
use Test::Exception;

{
    package MockFile;
    use Moose;

    sub fullpath { '/tmp/foo.png' }
    sub mimetype { 'mock/clanger' }

    no Moose;
    1;
}
    
use_ok('RSP::JSObject::Image');

my $file = MockFile->new();
my $image = RSP::JSObject::Image->new($file);
isa_ok($image, 'RSP::JSObject::Image');

basic: {

    # XXX - throws_ok only supports REGEX or OBJECTS, not hashrefs, etc.
    # so we have to use dies_ok =0(
    dies_ok {
        RSP::JSObject::Image->new();
    } q{Image with no file dies};

    $Imager::HEIGHT = '200';
    is($image->get_height, 200, q{Height works correctly});

    $Imager::WIDTH = '300';
    is($image->get_width, 300, q{Width works correctly});

    $image->flip_horizontal;
    is($Imager::FLIP_DIRECTION, 'h', q{Horizontal flip works correctly});

    $image->flip_vertical;
    is($Imager::FLIP_DIRECTION, 'v', q{Vertical flip works correctly});
}

rotate: {
    $image->rotate(100);
    is($Imager::ROTATE_DEGREES, 100, q{Rotate works correctly});

    throws_ok {
        $image->rotate;
    } qr{no amount of degrees to rotate$}, q{Rotate requires number of degrees};
}

scale: {
    $image->scale({ xpixels => 50, ypixels => 50 });
    is($Imager::SCALE, q{constrain(50x50)}, q{Scale works correctly});
}

crop: {
    $image->crop({ width => 100, height => 300});
    is($Imager::CROP->{width}, 100, q{Crop works correctly});
}

save: {
    $image->save();
    is($Imager::SAVE_FILE, q{/tmp/foo.png}, q{Save without file works correctly});
    is($Imager::SAVE_MIME, q{clanger}, q{Save without file works correctly (mime)});

    $image->save(1);
    isnt($Imager::SAVE_FILE, q{/tmp/foo.png}, q{Save with file works correctly});
    is($Imager::SAVE_MIME, q{clanger}, q{Save with file works correctly (mime)});
    isa_ok($image->file, 'RSP::JSObject::File');
}

as_string: {
    $Imager::DATA = 'hahaha';
    my $data = $image->as_string(type => 'foo/flibble');
    is($data, 'hahaha', q{as_string works correctly});
    is($Imager::SAVE_MIME, 'flibble', q{as_string works correctly (mime)});
    is($Imager::SAVE_FILE, undef, q{as_string doesn't write to file});
}


