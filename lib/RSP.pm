package RSP;

use strict;
use warnings;

use base 'Mojo';
use Application::Config 'rsp.conf';

sub handler {
  my ($self, $tx) = @_;

  my $request = $tx->req;  
  eval {
    my $rsptx   = RSP::Transaction->new;
    $rsptx->request( $tx->req );
    $rsptx->response( $tx->res );
    $rsptx->bootstrap;
    $rsptx->run;
    $rsptx->end;
    $rsptx = undef;
  };
  if ($@) {
    $tx->res->code( 500 );
    $tx->res->headers->content_type('text/plain');
    $tx->res->body($@);
  }
  return $tx;
}

1;
