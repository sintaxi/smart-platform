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
use Scalar::Util 'weaken';
use RSP::JSObject::File;

use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;

  RSP::JSObject::File->bind( $tx->context );
  
  return {
    'filesystem' => {
      'get' => sub {
        my $rsp_path  = shift;
        my $real_path = $tx->host->file( 'web', $rsp_path );
        $tx->log( "RSP Path is $rsp_path, real path is $real_path" );
        return RSP::JSObject::File->new( $real_path, $rsp_path );
      }
    }
  };
}


1;
