package RSP::Extension::HTTPRequest;

use strict;
use warnings;

use File::Basename qw( basename );
use RSP::JSObject::File;

use base 'RSP::Extension';

sub should_provide {
  my $class = shift;
  my $tx    = shift;
  return $tx->isa('RSP::Transaction::Mojo');
}

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

  my $request = {};
  eval {
    $request->{uri}     = $tx->request->url->path->to_string;
    $request->{method}  = $tx->request->method;
    $request->{query}   = $tx->request->query_params->to_hash;
    $request->{body}    = $tx->request->body_params->to_hash;
    $request->{cookies} = $cookies;


    if ( $tx->request->is_multipart ) {
      $request->{uploads} = {
			     map {
			       my $name = $_->name;
			       my $file = $_->file;
			       ( $name => RSP::JSObject::File->new( $file->path, basename( $_->filename ) ) )
			     } @{ $tx->request->uploads }
			    };
    } else {
      $request->{content} = $tx->request->body;
    }
    $request->{headers} = {
			   map {
			     ( lc($_) => $tx->request->headers->header($_) )
			   } @{ $tx->request->headers->names }
			  };

    $request->{queryString} = $tx->request->url->query->to_string;
  };

  if ($@) {
    print "couldn't bind request: $@\n";
  }
  return { request => $request };
}

1;
