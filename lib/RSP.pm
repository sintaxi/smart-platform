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

  my $ib = $req->content;
  my $ib_bw = do { use bytes; length( $ib ); };
  
  my $tx = RSP::Transaction->start( $req ); 
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
  
  my $resp  = HTTP::Response->new( @$op );

  my $ob = $resp->content;
  my $ob_bw = do { use bytes; length($ob); };

  $tx->log_billing( $ib_bw + $ob_bw, "bandwidth", );

  $tx->end;

  return $resp;
}

1;
