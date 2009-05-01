package RSP::Transaction::Mojo;

use strict;
use warnings;

use base 'RSP::Transaction';
use File::Basename;
use RSP::Transaction::Mojo::HostMap;

sub hostname {
  my $self = shift;
  if (!$self->{hostname}) {
    my $mapmeth = RSP->config->{mojo}->{hostmapper} || 'hostname';
    $self->{hostname} = RSP::Transaction::Mojo::HostMap->$mapmeth( $self->request );
  }
  return $self->{hostname};
}

##
## turns the response from the code into the Mojo::Message object
## that the web server needs.
##
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
      $self->response->body( $body->as_string( type => $self->response->headers->content_type ) );
    } else {
      ##
      ## we don't know what to do with it.
      ##
      die "don't know what to do with " . ref($body) . " object";
    }
  }

  ## I guess I should comment this -- if the application doesn't set a content-length header
  ## then we need to do it for them.  Its just polite.
  if ( !$self->response->headers->content_length ) {
    $self->response->headers->content_length( $self->response->content->body_length );
  }

}

##
## return the HTTP request object translated into something that
##  JavaScript can process
##
sub build_entrypoint_arguments {
  my $self = shift;

  my $cookies = {};
  if ( $self->request->cookies ) {
    foreach my $cookie ( @{ $self->request->cookies } ) {
      my $name  = $cookie->name;
      my $value = $cookie->value->to_string;
      $cookies->{$name} = "$value";
    }
  }

  my %body  = %{$self->request->body_params->to_hash};
  my %query = %{$self->request->query_params->to_hash};

  my $request = {};
  eval {
    $request->{type}    = 'HTTP';
    $request->{uri}     = $self->request->url->path->to_string;
    $request->{method}  = $self->request->method;
    $request->{query}   = \%query,
    $request->{body}    = \%body,
    $request->{cookies} = $cookies;

    ## if we've got a multipart request, don't bother with
    ## the content.
    if ( $self->request->is_multipart ) {
      ## map the uploads to RSP file objects
      $request->{uploads} = {
			     map {
			       my $name = $_->name;
			       my $file = $_->file;
			       ( $name => RSP::JSObject::File->new( $file->path, basename( $_->filename ) ) )
			     } @{ $self->request->uploads }
			    };
    } else {
      $request->{content} = $self->request->body;
    }

    $request->{headers} = {
			   map {
			     ( $_ => $self->request->headers->header($_) )
			   } @{ $self->request->headers->names }
			  };

    $request->{queryString} = $self->request->url->query->to_string;
  };

  if ($@) {
    print "couldn't bind request: $@\n";
  }

  return $request;
}

##
## this is mojo specific
##
sub bw_consumed {
  my $self = shift;
  my $ib = $self->inbound_bw_consumed;
  my $ob = $self->outbound_bw_consumed;
  return $ib + $ob;
}

sub outbound_bw_consumed {
  my $self = shift;
  bytes::length( $self->response->build() );
}

sub inbound_bw_consumed {
  my $self = shift;
  bytes::length( $self->request->build() );
}

1;
