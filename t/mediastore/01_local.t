#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';


use File::Temp qw(tempdir);
my $tmp_dir = tempdir();

basic: {
    use_ok('RSP::MediaStore::Local');

    my $media = RSP::Mediastore::Local->new(
        namespace => 'test.smart.joyent.com', 
        datadir => $tmp_dir
    );
    isa_ok($media, 'RSP::Mediastore::Local');

    my ($fname, $data) = ("foobar", "bazbashfoo");
    ok($media->write("test-data", $fname, $data), q{file written correctly});
    my $fobj = $media->get("test-data", $fname);
    ok($fobj, q{file retrieved correctly});
    isa_ok($fobj, q{RSP::JSObject::MediaFile::Local});

    ok($media->remove("test-data", $fname), q{file written correctly});
}

__END__
ok( my $ext_class = RSP::Extension::MediaStore->providing_class );
diag("providing class is $ext_class");

ok( my $provided = $ext_class->provides( $tx )->{mediastore} );

is( ref( $provided->{write} ), 'CODE' );

ok( $provided->{write}->( "test-data", $fname, $data ) );
ok( my $fobj = $provided->{get}->( "test-data", $fname ) );
ok( $provided->{remove}->( "test-data", $fname ) );

## clean up after ourselves...
if ( $ext_class->can('getmogile_adm') ) {
    ok( $ext_class->getmogile_adm->delete_domain(
	    $ext_class->domain_from_tx_and_type( $tx, "test-data" )
	), "domain should be gone...");
}

