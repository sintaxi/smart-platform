package RSP::Transaction::Mojo;

use strict;
use warnings;

use Encode;
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

sub encode_body {
  my $self = shift;
  my $body = shift;

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
      my $content = $self->context->call( $body );
      if ($@) { die $@ };
      $self->response->body( $content );
    } elsif ( ref($body) && $body->isa('RSP::JSObject') ) {
      if ( $body->isa('RSP::JSObject::File') ) {
	my $f = Mojo::File->new;
	$f->path( $body->fullpath );
	$self->response->content->file( $f );
      } else {
	##
	## it's an object that exists in both JS and Perl, convert it
	##  to it's stringified form, with a hint for the content-type.
	##
	$self->response->body(
			      $body->as_string( type => $self->response->headers->content_type )
			     );
      }
    } elsif  ( ref($body) && $body->isa('JavaScript::Generator') ) {
      my $resp = $self->response;
      $resp->headers->transfer_encoding('chunked');
      $resp->headers->trailer('X-Trailing');
      my $chunked = Mojo::Filter::Chunked->new;
      my $bytecount = bytes::length( $resp->build() ) + bytes::length( $self->request->build );
      $resp->body_cb(sub {
		       my $content  = shift;
		       my $result = $body->next();
		       if (!$result) {
			 my $header = Mojo::Headers->new;
			 $header->header('X-Trailing', 'true');
			 $self->end( 1 );  ## cleanup the transaction here because we couldn't do it earlier

			 $bytecount += bytes::length( $header->build );
			 my $bwreport = RSP::Consumption::Bandwidth->new();
			 $bwreport->count( $bytecount );
			 $bwreport->host( $self->hostname );
			 $bwreport->uri( $self->url );

			 $self->consumption_log( $bwreport );

			 return $chunked->build( $header );
		       } else {
			 $bytecount += bytes::length( $result );
			 return $chunked->build( $result );
		       }
		     });
    } else {
      ##
      ## we don't know what to do with it.
      ##
      die "don't know what to do with " . ref($body) . " object";
    }
  }

}

sub encode_array_response {
  my $self = shift;
  my $response = shift;
  my @resp = @$response;
  my ($code, $codestr, $headers, $body);
  if (@resp == 4) {
    ($code, $codestr, $headers, $body) = @resp;
  } elsif (@resp == 3) {
    ($code, $headers, $body) = @resp;
  }
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

  $self->encode_body( $body );
}

##
## turns the response from the code into the Mojo::Message object
## that the web server needs.
##
sub encode_response {
  my $self = shift;
  my $response = shift;

  if ( ref( $response ) && ref( $response ) eq 'ARRAY' ) {
    ## we're encoding a list...
    $self->encode_array_response( $response );
  } else {
    ## we're encoding a single thing...
    $self->response->headers->content_type( 'text/html' );
    $self->encode_body( $response );
  }

  $self->response->headers->remove('X-Powered-By');
  if ($self->response->headers->server =~ /Perl/) {
    $self->response->headers->server("Joyent Smart Platform (Mojo)/$RSP::VERSION");
  }

  if ( $self->response->headers->transfer_encoding &&
       $self->response->headers->transfer_encoding eq 'chunked' ) {
    $self->response->headers->remove('Content-Length');
  } else {
    if ( !$self->response->headers->content_length) {
      $self->response->headers->content_length( $self->response->content->body_size );
    }
  }

}

##
## terminates the transaction
##
sub end {
  my $self = shift;
  my $post_callback = shift;

  if ($post_callback || !($self->response->headers->transfer_encoding && $self->response->headers->transfer_encoding eq "chunked")) {
    $self->report_consumption;
    undef( $self->{cache} );
    $self->cleanup_js_environment;
  }
}

sub process_transaction {
  my $self = shift;
  $self->url( $self->request->url->path->to_string );
  $self->SUPER::process_transaction( @_ );
}

##
## return the HTTP request object translated into something that
##  JavaScript can process
##
sub build_entrypoint_arguments {
  my $self = shift;

  my $cookies;
  if ( $self->request->cookies ) {
    foreach my $cookie ( @{ $self->request->cookies } ) {
      my $name  = $cookie->name;
      my $value = $cookie->value->to_string;
      ## WAAAAAAH
      if ( exists $cookies->{ $name } ) {
	if ( ref( $cookies->{$name} ) ) {
	  push @{ $cookies->{ $name } }, $value;
	} else {
	  $cookies->{ $name } = [ $cookies->{ $name }, $value ];
	}
      } else {
	$cookies->{$name} = "$value";
      }
    }
  }

  my %body  = %{$self->request->body_params->to_hash};
  foreach my $key (keys %body) {
    $body{$key} = Encode::decode("utf8", $body{$key});
  }

  my %query = %{$self->request->query_params->to_hash};

  my $request = {};
  my $uploads = {};
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
      $uploads = {
		  map {
		    my $name = $_->name;
		    my $file = $_->file;
		    (
		     $name => RSP::JSObject::File->new(
						       $file->path, 
						       basename( $_->filename )
						      )
		    )
		  } @{ $self->request->uploads }
		 };
    } else {
      $request->{content} = Encode::decode( 'utf8', $self->request->body );
    }

    $request->{headers} = {
			   map {
			     my $val = scalar( $self->request->headers->header( $_ ) );
			     ( $_ => $val )
			   } @{ $self->request->headers->names }
			  };

    $request->{queryString} = $self->request->url->query->to_string;
  };

  $request->{uploads} = $uploads;

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
