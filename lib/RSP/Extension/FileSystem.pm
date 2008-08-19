#    This file is part of the RSP.
#
#    The RSP is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    The RSP is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with the RSP.  If not, see <http://www.gnu.org/licenses/>.

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
