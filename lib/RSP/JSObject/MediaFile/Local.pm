package RSP::JSObject::MediaFile::Local;

use strict;
use warnings;

use base 'RSP::JSObject::File',      # already implements a lot of what we need.
         'RSP::JSObject::MediaFile'; # base API


sub clearcache {
  warn("clearcache in " . __PACKAGE__ . " not yet implemented");
}

sub remove {
  my $self = shift;
  unlink( $self->fullpath );
}

sub md5 {
  my $self = shift;
  Digest::MD5::md5_hex( $self->contents );
}

1;
