package RSP::Extension::FileSystem;

use strict;
use warnings;

use JavaScript;

sub provide {
  my $class = shift;
  my $tx = shift;

  $tx->{context}->bind_class(
    name => 'RealFile',
    constructor => sub {
      return undef;
    },
    package => 'MyRSP::FileObject',
    properties => {
      'filename' => {
        'getter' => 'MyRSP::FileObject::filename',
      },
      'mimetype' => {
        'getter' => 'MyRSP::FileObject::mimetype',
      },
      'size' => {
        'getter' => 'MyRSP::FileObject::size',
      },
      'mtime' =>{
        'getter' => 'MyRSP::FileObject::mtime',
      },
      'exists' => {
        'getter' => 'MyRSP::FileObject::exists',
      }
    },
    methods => {
      'toString' => sub {
        use Data::Dumper; print Dumper( [@_] );
        return "hello";
      }
    },
    flags   => JS_CLASS_NO_INSTANCE
  );
  
  return (
    'filesystem' => {
      'get' => sub {
        my $fn = shift;
        return MyRSP::FileObject->new(
          File::Spec->catfile(
            $tx->webroot,
            $fn
          ),
          $fn
        );
      }
    }
  );
}

package MyRSP::FileObject;

use MIME::Types;
my $mimetypes = MIME::Types->new;

sub new {
  my $class = shift;
  my $fn    = shift;
  my $jsface = shift; ## javascript facing name
  if (!-e $fn) {
    die "$!: $jsface";
  }
  my $self  = { file => $fn, original => $jsface };
  bless $self, $class;
}

sub as_string {
  my $self = shift;
  my $fh   = IO::File->new( $self->{ file } );
  my $data = do {
    local $/;
    $fh->getline();
  };
  $fh->close;
  return $data;
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
