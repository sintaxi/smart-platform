#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use File::Temp qw(tempfile);

my $example_png = 't/data/icon.png';

use_ok('RSP::JSObject::File');

basic: {
    my $file = RSP::JSObject::File->new($example_png, 'icon.png');
    isa_ok($file, 'RSP::JSObject::File');
    
    is($file->mimetype, 'image/png', q{mimetype works correctly});
    is($file->filename, 'icon.png', q{filename works correctly});
    is($file->fullpath, $example_png, q{fullpath works correctly});
    is($file->size, (-s $example_png), q{size works correctly});
    is($file->exists, 1, q{exists works correctly});
    is($file->mtime, (stat($example_png))[9], q{mtime works correctly});
}

slurp: {
    raw: {
        my ($fh, $filename) = tempfile();
        print {$fh} "1234"; $fh->flush;
        
        my $file = RSP::JSObject::File->new($filename, 'foo.png');
        is($file->raw, '1234', q{raw works worrectly});
        unlink $filename;

        throws_ok {
            $file->raw;
        } qr{could not open \Q$filename\E: [^\n]+$}, q{raw throws exception on disappearing file};
    }

    as_string: {
        my ($fh, $filename) = tempfile();
        print {$fh} "1234"; $fh->flush;

        my $file = RSP::JSObject::File->new($filename, 'foo.txt');
        is($file->as_string, '1234', q{as_string works correctly});

        $file = RSP::JSObject::File->new($filename, 'foo.png');
        is($file->as_string, '1234', q{as_string works correctly});
    }

    as_function: {
         my ($fh, $filename) = tempfile();
        print {$fh} "1234"; $fh->flush;

        my $file = RSP::JSObject::File->new($filename, 'foo.txt');
        is($file->as_function->(), '1234', q{as_function works correctly});
   
    }
}

failures: {
    throws_ok {
        RSP::JSObject::File->new('/tmp/asjdlkasjdlkasjdalskj.foo', 'bob.txt');
    } qr{[^\n:]+: bob\.txt$}, q{non-existant file throws exception};
}
