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
package RSP::Extension::HTTP;

use strict;
use warnings;

use LWPx::ParanoidAgent;
use HTTP::Request;

use base 'RSP::Extension';


our $VERSION = '1.00';

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $ua = LWPx::ParanoidAgent->new;
  $ua->agent("Reasonably Smart Platform / HTTP / $VERSION");
  $ua->timeout( 10 );  
  return {
    'http' => {
      'request' => sub {
        my $response = eval {
          my $req = shift;
          my $r;
          if ( ref( $req ) ) {
            $r = HTTP::Request->new( @$req );
          } else {
            $r = HTTP::Request->new( $req, @_ );
          }
          $ua->request( $r );
        };
        if ($@) {
          die "error: $@";
        }
        return $class->response_to_object( $response );
      }
    }
  };
}

sub response_to_object {
  my $class = shift;
  my $response = shift;
  my %headers = %{ $response->{_headers} };
  return {
    'headers'=> \%headers,
    'content' => $response->decoded_content
  }
}

1;
