package RSP::JSObject::MediaFile::Local;

use strict;
use warnings;

use File::MMagic;

use base 'RSP::JSObject::MediaFile', # base API
         'RSP::JSObject::File';      # already implements a lot of what we need.


sub new {
  my $class = shift;
  bless RSP::JSObject::File->new( @_ ), $class;
}

sub clearcache {}

sub remove {
  my $self = shift;
  unlink( $self->fullpath );
}

sub md5 {
  my $self = shift;
  Digest::MD5::md5_hex( $self->as_string );
}

sub mimetype {
  my $self = shift;
  my $mm = File::MMagic->new;
  my $mime = $mm->checktype_contents( $self->raw );
  return $mime;
}

1;
