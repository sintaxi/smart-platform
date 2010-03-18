package RSP::Mediastore::Local;

use Moose;
use namespace::autoclean;
use strict;
use warnings;

use Scalar::Util qw( blessed );

use File::Path;
use File::Copy;
use File::Spec;
use Digest::MD5 qw( md5_hex );
use IO::File;
use RSP::JSObject::MediaFile::Local;

has datadir => (is => 'ro', isa => 'Str', required => 1);
has namespace => (is => 'ro', isa => 'Str', required => 1);
has namespace_sum => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_namespace_sum {
    my ($self) = @_;
    return md5_hex($self->namespace);
}

sub bind_class {
  return 'RSP::JSObject::MediaFile::Local';
}

sub storage_dir {
  my ($self, $type) = @_;
  my $dataroot = $self->datadir;
  my $nspath   = substr($self->namespace_sum, 0, 2);
  my $storedir = File::Spec->catfile( $dataroot, $nspath, $self->namespace . ".store", $type );
}

sub storage_path {
  my ($self, $type, $name) = @_;
  File::Spec->catfile( $self->storage_dir( $type ), $name );
}

sub write {
  my ( $self, $type, $name, $data ) = @_;
  if (!defined( $name )) { die "no name" }
  if (!defined( $data )) { die "no data" }

  #$self->bind_class->clearcache( $tx, $name );

  my $storedir  = $self->storage_dir( $type );
  my $storefile = $self->storage_path( $type, $name );

  if (!-d $storedir) {
    mkpath( $storedir );
  }
  if ( blessed( $data ) ) {
    if (!File::Copy::copy( $data->fullpath, $storefile )) {
      my $filename = $data->fullpath;
      die "couldn't copy data from $filename to $type/$name: $!\n";
    }
  } else {
    my $fh = IO::File->new( $storefile, ">" );
    if (!$fh) {
      die "couldn't create file $type/$name: $!\n";
    }
    $fh->print( $data );
    $fh->close or die "couldn't close the file $type/$name: $!\n";
  }
  return 1;
}

sub get {
  my ( $self, $type, $name ) = @_;
  my $path = $self->storage_path( $type, $name );
  my $obj = eval {
    my $obj = $self->bind_class->new( $path, $name );
  };
  if ($@) {
      chomp($@);
      die "could not bind object for file $name: $@\n";
  }
  return $obj;
}

sub remove {
  my ( $self, $type, $name ) = @_;
  $self->get( $type, $name )->remove();
}

__PACKAGE__->meta->make_immutable;
1;
