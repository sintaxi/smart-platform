package RSP::Transaction::Mojo;

use strict;
use warnings;

use base 'RSP::Transaction';

sub encode_response {
  my $self = shift;
  my $response = shift;

  my @resp = @$response;

  my ($code, $codestr, $headers, $body) = @resp;
  $self->response->code( $code );
  my @headers = @$headers;
  while( my $key = shift @headers ) {
    my $value = shift @headers;
    ## why do we need to special case this?
    if ( $key eq 'Set-Cookie') {
      my $cookies = Mojo::Cookie::Response->new->parse( $value );
      $self->response->cookies( $cookies->[0] );
    } else {
      $self->response->headers->add_line( $key, $value );
    }
  }
  
  ##
  ## if we have a simple body string, use that, otherwise
  ##  we need to be a bit more clever
  ##
  if (!ref($body)) {
    $self->response->body( $body );
  } else {
    if ( ref($body) eq 'JavaScript::Function' ) {
      ## it's a javascript function, call it and use the
      ## returned data
      $self->response->body( $body->() );
    } elsif ( ref($body) && $body->isa('RSP::JSObject') ) {
      ##
      ## it's a blended object, most likely ( at this point ) a file.
      ##   suck the data up and use that
      ##
      $self->response->body( $body->as_string );
    } else {
      ##
      ## we don't know what to do with it.
      ##
      die "don't know what to do with " . ref($body) . " object";
    }
  }
}

1;
