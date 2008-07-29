package RSP::Extension::FileSystem;

use strict;
use warnings;

use JavaScript;
use RSP::JSObject::File;

sub provide {
  my $class = shift;
  my $tx = shift;

  $tx->{context}->bind_class(
    name => 'RealFile',
    constructor => sub {
      return undef;
    },
    package => 'RSP::JSObject::File',
    properties => {
      'filename' => {
        'getter' => 'RSP::JSObject::File::filename',
      },
      'mimetype' => {
        'getter' => 'RSP::JSObject::File::mimetype',
      },
      'size' => {
        'getter' => 'RSP::JSObject::File::size',
      },
      'mtime' =>{
        'getter' => 'RSP::JSObject::File::mtime',
      },
      'exists' => {
        'getter' => 'RSP::JSObject::File::exists',
      }
    },
    methods => {
      'toString' => sub {
        my $self = shift;
        return $self->filename;
      }
    },
  );
  
  return (
    'filesystem' => {
      'get' => sub {
        my $fn = shift;
        my $fullpath = File::Spec->catfile( $tx->webroot, $fn );
        my $file = eval {
          RSP::JSObject::File->new( $fullpath, $fn );
        };
        if ($@) {
          return undef;
        }
        return $file;
      }
    }
  );
}


1;
