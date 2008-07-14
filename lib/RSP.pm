package RSP;

use strict;
use warnings;

use URI;
use JavaScript;
use RSP::Config;
use RSP::Transaction;

use Module::Load ();
use HTTP::Response;

sub handle {
  my $class = shift;
  my $req   = shift;

  my $rt = JavaScript::Runtime->new;
  my $cx = $rt->create_context;
  my $tx = RSP::Transaction->start( $cx, $req ); 
  my $resp  = HTTP::Response->new( @{ $tx->run } );
  $tx->end;
  return $resp;
}

1;
