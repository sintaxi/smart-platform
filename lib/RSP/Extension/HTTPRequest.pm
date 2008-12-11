package RSP::Extension::HTTPRequest;

use strict;
use warnings;

sub provides {
  my $class = shift;
  my $tx    = shift;
  
  return {
    'request' => {
      'uri'    => $tx->request->url->path->to_string,
      'method' => $tx->request->method,
      'query'  => $tx->request->query_params->to_hash,
      'body'   => $tx->request->body_params->to_hash,
      'headers'=> { map {
        ( $_ => $tx->request->headers->header($_) )
      } $tx->request->headers->names },
      'queryString' => $tx->request->url->query->to_string,
    }  
  };
}

1;
