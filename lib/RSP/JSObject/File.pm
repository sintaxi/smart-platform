package RSP::JSObject::File;

use Moose;
with qw(RSP::Role::JSObject);

use IO::File;
use Encode;
use MIME::Types;
my $mimetypes = MIME::Types->new;

has file => (is => 'rw', isa => 'Str');
has original => (is => 'rw', isa => 'Str');

sub BUILDARGS {
    my ($self, $file, $jsname) = @_;
    die "$!: $jsname\n" if !-e $file;
    return { file => $file, original => $jsname };
}

sub as_function {
  my $self = shift;
  return sub {
    return $self->as_string;
  };
}

sub raw {
  my $self = shift;
  my $fh   = IO::File->new( $self->{ file } );
  if (!$fh) {
      die "could not open $self->{file}: $!\n";
  }
  my $data = do {
    local $/;
    $fh->getline();
  };
  $fh->close;
  return $data;
}

sub as_string {
  my $self = shift;
  my $data = $self->raw;

  if ( $self->mimetype =~ /text/ ) {
    return Encode::decode("utf8", $data);
  } else {
    return $data;
  }
}

sub mimetype {
  my $self = shift;
  $self->{original} =~ /\.(\w+)$/;
  my $ext = $1;
  return $mimetypes->mimeTypeOf( $ext )."";
}

## returns the javascript-facing filename
sub filename {
  my $self = shift;
  return $self->{original}
}

sub fullpath {
  my $self = shift;
  return $self->{file};
}

sub size {
  my $self = shift;
  return -s $self->{file};
}

sub exists {
  my $self = shift;
  return -e $self->{file};
}

sub mtime {
  my $self = shift;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
      $atime,$mtime,$ctime,$blksize,$blocks)
      = stat($self->{file});  
  return $mtime;
}

1;
