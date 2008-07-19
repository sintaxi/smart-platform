package RSP::Apache2::Authen;

use strict;
use warnings;

use Apache2::Access ();
use Apache2::RequestUtil ();

use JSON::XS;
use HTTP::Request;
use RSP::Transaction;
use RSP::ObjectStore;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);

use constant SECRET_LENGTH => 14;

sub handler {
    my $r = shift;

    my ($status, $password) = $r->get_basic_auth_pw;
    return $status unless $status == Apache2::Const::OK;

    my $host = $r->headers_in->{Host};    
    my $mgmt = RSP->config->{_}->{ManagementHost}; 

    my $tx   = RSP::Transaction->new( HTTP::Request->new( 'GET', '/', [ 'Host' => $host ] ) );
    my $os   = RSP::ObjectStore->new( $tx->dbfile );
    
    my $set  = $os->query("hostname" => "=" => JSON::XS::encode_json( $host ));
    my $hid  = ($set->members)[0];
    
    my $auth  = {};
    my $parts = $os->get($hid);
    foreach my $part (@$parts) {
      my $name  = $part->[0];
      my $value = $part->[1];
      if ( $name eq 'committers' ) {
        $auth = JSON::XS::decode_json( $value );
        last;
      }
    }
    
    return Apache2::Const::OK if ( $password eq $auth->{$r->user}->{password});
    
    $r->note_basic_auth_failure;
    return Apache2::Const::HTTP_UNAUTHORIZED;
}

1;