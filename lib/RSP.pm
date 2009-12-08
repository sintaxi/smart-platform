package RSP;

use strict;
use warnings;

use Cwd;
use base 'Mojo';
use Scalar::Util qw( weaken );
our $VERSION = '1.2';
use Application::Config 'rsp.conf';

use RSP::Config;

our $CONFIG;
sub conf {
    my $class = shift;
    if(!$CONFIG){
        $CONFIG = RSP::Config->new(config => { %{ $class->config } });
    }
    return $CONFIG;
}

use RSP::Transaction::Mojo;

sub handler {
  my ($self, $tx) = @_;

  my $rsptx = RSP::Transaction::Mojo->new
                                    ->request( $tx->req )
				    ->response( $tx->res );

      use Carp::Always;
    use Try::Tiny;
    try {
        $rsptx->process_transaction;
        die $@ if $@;
    } catch {
        $tx->res->code(500);
        $tx->res->headers->content_type('text/plain');
        $tx->res->body($_);
        $rsptx->log($_);
    };

    #$rsptx->request( undef );
    #$rsptx->response( undef );
    #$rsptx = undef;

  return $tx;
}

sub root {
  my $self = shift;
  return $self->conf->root;
}

1;
