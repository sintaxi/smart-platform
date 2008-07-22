package RSP::Apache2::Response;

use strict;
use warnings;

use RSP;
use HTTP::Request;
use HTTP::Request::Common;
use Apache2::Request;
use Apache2::Const -compile => 'OK';
use Apache2::RequestIO;
use Apache2::RequestUtil;
use Apache2::RequestRec;

sub handler {
  my $r = shift;
  my $ap = Apache2::Request->new( $r );
  my $req = HTTP::Request->parse( $r->as_string );

  ## is there not a better way to get the unparsed body? surely...
  my $postparams = [];
  foreach my $param ( $ap->param ) {
    push @$postparams, $param, $ap->param($param);
  }
  my $rp = POST('/',$postparams);  
  $req->content( $rp->content );

  warn("request is " . $req->as_string);

  my $res = RSP->handle( $req );

  $r->status( $res->code );
  $r->status_line( $res->message );
  my $ho  = $r->err_headers_out;
  foreach my $header ( $res->headers->header_field_names() ) {
    next if ( $header eq 'Content-Type' );
    warn("setting header $header");
    my $val = $res->header( $header );
    warn("setting $header to $val");
    eval {
      $ho->set( $header, $res->header( $header ) );
    };
    if ($@) {
      warn("could not set '$header' to '$val': $@");
    }
  }
  $r->content_type( $res->header('Content-Type') );
  $r->print( $res->content );

  return Apache2::Const::OK;
}

1;

