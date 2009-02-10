package RSP::Extension::MediaStore::Local;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use File::Copy;
use RSP::JSObject::MediaFile::Local;

use base 'RSP::Extension::MediaStore';

sub bind_class {
  return 'RSP::JSObject::MediaFile::Local';
}

sub remove {
  my ( $self, $tx, $name ) = @_;
  $self->bind_class->remove;
}

sub write {
  my ( $self, $tx, $name, $data ) = @_;
  if (!defined( $name )) { die "no name" }
  if (!defined( $data )) { die "no data" }

  $self->bind_class->clearcache( $tx, $name );
  eval {
    if ( blessed( $data ) ) {
      $self->bind_class->new_with_object( $data )->save;
    } else {
      $self->
    }
  };
}

sub get {
  my ( $self, $tx, $name ) = @_;
  my $file_object;
  return $file_object;
}

1;
