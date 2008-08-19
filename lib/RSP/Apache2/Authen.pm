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
package RSP::Apache2::Authen;

use strict;
use warnings;

use Apache2::Access ();
use Apache2::RequestUtil ();

use JSON::XS;
use HTTP::Request;
use RSP::Config;
use RSP::Transaction;
use RSP::ObjectStore;
use Apache2::RequestRec;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);

use constant SECRET_LENGTH => 14;

my $coder = JSON::XS->new->allow_nonref->utf8;

sub handler {
    my $r = shift;

    my ($status, $password) = $r->get_basic_auth_pw;
    return $status unless $status == Apache2::Const::OK;

    my $host = $r->headers_in->{Host};    
    $host =~ s/\:\d+$//;
    my $mgmt = RSP->config->{_}->{ManagementHost}; 

    my $tx   = RSP::Transaction->start( HTTP::Request->new( 'GET', '/', [ 'Host' => $mgmt ] ) );
    my $os   = RSP::ObjectStore->new( $tx->dbfile );

    
    my $set  = $os->query("hostname" => "=" => $coder->encode( $host ));
   my $hid  = ($set->members)[0];
    if ($hid) {
      my $auth  = {};
      my $parts = $os->get($hid);
      foreach my $part (@$parts) {
        my $name  = $part->[0];
        my $value = $part->[1];
	if ( $name eq 'committers' ) {
          my $auth = $coder->decode( $value );
	  if ( $password eq $auth->{$r->user}->{password} ) {  
            return Apache2::Const::OK;
          }
	}
      }
    }

    $tx->end;   

    
    $r->note_basic_auth_failure;
    return Apache2::Const::HTTP_UNAUTHORIZED;
}

1;
