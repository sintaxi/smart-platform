package RSP;

use strict;
use warnings;

use URI;
use JavaScript;
use RSP::Config;
use RSP::Transaction;

use Scalar::Util qw( blessed );
use Module::Load ();
use HTTP::Response;

sub handle {
  my $class = shift;
  my $req   = shift;

  my $tx = RSP::Transaction->start( $req ); 
  my $op = $tx->run;
 
  ## handle blessed objects, like filesystem objects...
  if ( blessed( $op->[ 3 ] ) ) {
    $op->[3] = $op->[3]->as_string;
  }
  
  my $resp  = HTTP::Response->new( @$op );
  $tx->end;
  return $resp;
}

1;
