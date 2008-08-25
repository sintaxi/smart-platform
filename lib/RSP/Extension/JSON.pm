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
package RSP::Extension::JSON;

use strict;
use warnings;

use JSON::XS;

my $encoders = [  JSON::XS->new->utf8, JSON::XS->new->utf8->pretty];

sub provide {
  return (
    'json' => {
      'encode' => sub {
        my $data   = shift;
        return $encoders->[shift||0]->encode( $data );        
      },
      'decode' => sub {
        my $text = shift;
        return $encoders->[0]->decode( $text );
      }
    }
  );
}

1;
