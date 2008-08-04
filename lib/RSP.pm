package RSP;

use strict;
use warnings;

use URI;
use Encode;
use JavaScript;
use RSP::Config;
use RSP::Transaction;

use Scalar::Util qw( blessed );
use Module::Load ();
use HTTP::Response;

sub handle {
  my $class = shift;
  my $req   = shift;

  my $ib = Encode::encode("ascii", $req->as_string );
  my $ib_bw = length( $ib );
  
  my $tx = RSP::Transaction->start( $req ); 
  my $op = $tx->run;
 
  ## handle blessed objects, like filesystem objects...
  if ( blessed( $op->[ 3 ] ) ) {
    $op->[3] = $op->[3]->as_string;
  }
  
  my $resp  = HTTP::Response->new( @$op );

  my $ob = Encode::encode("ascii", $resp->as_string );
  my $ob_bw = length($ob);

  $tx->log_billing( $ib_bw + $ob_bw, "bandwidth", );

  $tx->end;

  return $resp;
}

1;
