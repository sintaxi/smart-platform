package RSP;

use strict;
use warnings;

use Cwd;
use base 'Mojo';
use Scalar::Util qw( weaken );
our $VERSION = '1.2';
use Application::Config 'rsp.conf';

use RSP::Transaction::Mojo;

sub handler {
  my ($self, $tx) = @_;

  my $rsptx = RSP::Transaction::Mojo->new
                                    ->request( $tx->req )
				    ->response( $tx->res );

  eval {
    $rsptx->process_transaction;
  };
  if ($@) {
    my $error_message = $@;
    if ($error_message =~ /in file (.+\.pm) at line (.+)$/) {
      $error_message =~ s/in file (.+\.pm) at line (.+)$//;
    }
    $tx->res->code( 500 );
    $tx->res->headers->content_type('text/plain');
    $tx->res->body($error_message);
  }

  $rsptx->request( undef );
  $rsptx->response( undef );
  $rsptx = undef;

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
