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
