package RSP::Extension::MediaStore::Local;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use File::Path;
use File::Copy;
use File::Spec;
use Digest::MD5 qw( md5_hex );
use RSP::JSObject::MediaFile::Local;

use base 'RSP::Extension::MediaStore';

sub bind_class {
  return 'RSP::JSObject::MediaFile::Local';
}

sub storage_dir {
  my $self = shift;
  my $tx   = shift;
  my $type = shift;
  my $dataroot = RSP->config->{localstorage}->{data} // '';
  my $nspath   = substr(md5_hex( $tx->hostname ), 0, 2);
  my $storedir = File::Spec->catfile( $dataroot, $nspath, $tx->hostname . ".store", $type );
}

sub storage_path {
  my $self = shift;
  my $tx   = shift;
  my $type = shift;
  my $name = shift;
  File::Spec->catfile( $self->storage_dir( $tx, $type ), $name );
}

sub write {
  my ( $self, $tx, $type, $name, $data ) = @_;
  if (!defined( $name )) { die "no name" }
  if (!defined( $data )) { die "no data" }

  $self->bind_class->clearcache( $tx, $name );

  my $storedir  = $self->storage_dir( $tx, $type );
  my $storefile = $self->storage_path( $tx, $type, $name );

  if (!-d $storedir) {
    mkpath( $storedir );
  }
  if ( blessed( $data ) ) {
    if (!File::Copy::copy( $data->fullpath, $storefile )) {
      my $filename = $data->fullpath;
      RSP::Error->throw("couldn't copy data from $filename to $type/$name: $!");
    }
  } else {
    my $fh = IO::File->new( $storefile, ">" );
    if (!$fh) {
      RSP::Error->throw("couldn't create file $type/$name: $!");
    }
    $fh->print( $data );
    $fh->close or RSP::Error->throw("couldn't close the file $type/$name: $!");
  }
  return 1;
}

sub get {
  my ( $self, $tx, $type, $name ) = @_;
  my $path = $self->storage_path( $tx, $type, $name );
  my $obj = eval {
    my $obj = $self->bind_class->new( $path, $name );
  };
  if ($@) {
    RSP::Error->throw("could not bind object for file $name: $@");
  }
  return $obj;
}

sub remove {
  my ( $self, $tx, $type, $name ) = @_;
  $self->get( $tx, $type, $name )->remove();
}

1;
