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
    my $os   = RSP::ObjectStore::Storage->new( $tx->dbfile );

    
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
