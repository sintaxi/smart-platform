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
package RSP::Extension::Request;

use strict;
use warnings;

use URI::Escape;
use URI::QueryParam;

sub provide {
  my $class = shift;
  my $tx    = shift;

  my $req = $tx->{request};
  my $uri = uri_unescape($req->uri->path);
  my $qp  = $req->uri->query_form_hash;
  my %headers = %{ $req->{_headers} };
  return (
    'request' => {
      'method' => $req->method,
      'uri'    => uri_unescape( $uri ),
      'query'  => $qp,
      'headers'=> \%headers,
      'content' => $req->decoded_content
    }
  );
}

1;
