package RSP::Extension::HTTPRequest;

use strict;
use warnings;

sub provides {
  my $class = shift;
  my $tx    = shift;

  my $cookies = {};
  if ( $tx->request->cookies ) {
    foreach my $cookie ( @{ $tx->request->cookies } ) {
      my $name  = $cookie->name;
      my $value = $cookie->value->to_string;
      $cookies->{$name} = "$value";
    }
  }
  
  return {
    'request' => {
      'uri'    => $tx->request->url->path->to_string,
      'method' => $tx->request->method,
      'query'  => $tx->request->query_params->to_hash,
      'body'   => $tx->request->body_params->to_hash,
      'headers'=> { map {
        ( lc($_) => $tx->request->headers->header($_) )
      } @{$tx->request->headers->names} },
      'queryString' => $tx->request->url->query->to_string,
      'cookies' => $cookies,
      'content' => $tx->request->body
    }  
  };
}

1;
