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

package RSP;

use strict;
use warnings;

use URI;
use Encode;
use JavaScript;
use RSP::Config;
use RSP::Transaction;

our $VERSION = '1.00';

use Devel::Peek;

use Scalar::Util qw( blessed );
use Module::Load ();
use HTTP::Response;

sub handle {
  my $class = shift;
  my $req   = shift;
  my $hints = shift;

  my $ib = $req->content;
  my $ib_bw = do { use bytes; length( $ib ); };
  
  my $tx = RSP::Transaction->start( $req, $hints ); 

  my $op = $tx->run;
 
  ## handle blessed objects, like filesystem objects...
  if ( blessed( $op->[ 3 ] ) ) {
    my $fn = $op->[3]->as_function;  
    my $result = eval {
      my $answer = $fn->();
      $answer;
    };
    if ($@) { warn "error getting content from blessed content handler: $@" }
    $op->[3] = $result;
  }
  
  $op->[3] = encode("iso-8859-1", $op->[3]);
  my $resp  = HTTP::Response->new( @$op );

  my $ob = $resp->content;
  my $ob_bw = do { use bytes; length($ob); };

  $tx->log_billing( $ib_bw + $ob_bw, "bandwidth", );

  $tx->end;

  return $resp;
}

1;

=head1 NAME

RSP - The Reasonably Smart Platform

=head1 SYNOPSIS

  use RSP;
  my $http_response = RSP->handle( $http_request );

=head1 DESCRIPTION

The Reasonably Smart Platform is a platform-as-a-service offering that provides
a JavaScript application development environment in a simple fashion, so that
frameworks, libraries and applications can be crafted on top of it.

=head1 CLASS METHODS

=over 4

=item HTTP::Response handle( HTTP::Request theRequest )

The C<handle> method takes an HTTP::Request object and routes it to the
appropriate JavaScript application for the host.  It relies on HTTP/1.1
to determine the hostname for the routing of the request.

C<handle> returns an HTTP::Response object for you to serve immediately
via a perl mechanism, or convert to something else.

=back

=head1 SEE ALSO

=over 4

=item RSP::Transaction

=item RSP::Config

=item RSP::Apache2

=item RSP::Server

=back

=head1 AUTHOR

James A. Duncan <james@reasonablysmart.com>

=head1 LICENSE

This file is part of the RSP.

The RSP is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The RSP is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the RSP.  If not, see <http://www.gnu.org/licenses/>.

=cut
