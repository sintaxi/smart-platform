package RSP;

use strict;
use warnings;

use Cwd;
use base 'Mojo';
our $VERSION = '1.2';
use Application::Config 'rsp.conf';

use RSP::Transaction::Mojo;

sub handler {
  my ($self, $tx) = @_;

  eval {
    my $rsptx = RSP::Transaction::Mojo->new
                                      ->request( $tx->req )
                                      ->response( $tx->res );

    $rsptx->process_transaction;
    $rsptx = undef;
  };
  if ($@) {
    $tx->res->code( 500 );
    $tx->res->headers->content_type('text/plain');
    $tx->res->body($@);
  }
  return $tx;
}

sub root {
  my $self = shift;
  my $root = $self->config->{_}->{root};
  if (!$root) {
    $root = getcwd();
  }
  return $root;
}

1;
