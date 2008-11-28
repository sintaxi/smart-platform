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

use HTTP::Body;
use URI::Escape;
use URI::QueryParam;

sub provide {
  my $class = shift;
  my $tx    = shift;

  my $req = $tx->{request};
  my $uri = uri_unescape($req->uri->path);
  my $qp  = $req->uri->query_form_hash;
  my %headers = %{ $req->{_headers} };

  my $body = {};
  if (!$tx->{hints}->{original_request} && $req->method =~ /^(post|put)$/i) {
    ## 'cause firefox is probably right, but HTTP::Body doesn't like it
    my $type = $req->content_type;
    $type =~ s/;.+$//;
    $body = HTTP::Body->new(
      $type,
      $req->content_length,
    );
    $body->add($req->content);
    $body = $body->param;
  } elsif ($tx->{hints}->{original_request}) {
    my $r  = $tx->{hints}->{original_request};
    my $ap = Apache2::Request->new( $r ); 
    foreach my $param ( $ap->param ) {
      my @values = $ap->param($param);
      if ( scalar(@values) > 1 ) {
        $body->{$param} = \@values;
      } else {
	$body->{$param} = $values[0];
      }
    }
  }

  return (
    'request' => {
      'method' => $req->method,
      'uri'    => uri_unescape( $uri ),
      'query'  => $qp,
      'headers'=> \%headers,
      'content' => $req->decoded_content,
      'body'    => $body
    }
  );
}

1;
