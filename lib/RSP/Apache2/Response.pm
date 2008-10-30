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

  if ( $r->method eq 'POST') {
    ## is there not a better way to get the unparsed body? surely...
    my $postparams = [];
    foreach my $param ( $ap->param ) {
      my $value = $ap->param($param);
      push @$postparams, $param, $value;
    }
    my $rp = POST('/',$postparams);  
    $req->content( $rp->content );
  } else {
    my $content;
    my $len = $r->headers_in->{'Content-Length'};
    if ( $len ) {
      $r->read( $content, $len );
      $req->content( $content );
    }
  }

  my $res = RSP->handle( $req, { original_request => $r } );

  $r->status( $res->code );
  if ( $res->message ) {
    $r->status_line( $res->message );
  }
  my $ho  = $r->err_headers_out;
  foreach my $header ( $res->headers->header_field_names() ) {
    next if ( $header eq 'Content-Type' );
    my $val = $res->header( $header );
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

