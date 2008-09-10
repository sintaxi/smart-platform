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
package RSP::Extension::Digest;

use strict;
use warnings;

use Digest::MD5 qw( md5_hex md5_base64 );


=head1 Name

Digest - md5 digests for the RSP

=head1 Structure

=over 4

=item digest

=over 4

=item md5

=over 4

=item String hex( String data )

Returns the md5 hex digest calculation for data.

=item String base64( String data )       

Returns the base64 encoded md5 digest for data.

=cut        


sub provide {
  my $class = shift;
  my $tx    = shift;
  return (

    'digest' => {

      'md5' => {
        'hex' => sub {
          my $data = shift;
          if ( ref( $data )) {
            $data = $data->as_string;
          }
          return md5_hex( $data );
        },
        'base64' => sub {
          my $data = shift;
          if ( ref( $data )) {
            $data = $data->as_string;
          }
          return md5_base64( $data );
        }
      }
    }
  );
}

1;
