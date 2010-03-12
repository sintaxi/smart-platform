package RSP;

use Moose;
use Cwd;
use base 'Mojo';
use Scalar::Util qw( weaken );
our $VERSION = '1.2';
use Application::Config 'rsp.conf';

use RSP::Config;
use Try::Tiny;
#      use Carp::Always;

our $CONFIG;
sub conf {
    my $class = shift;
    if(!$CONFIG){
        $CONFIG = RSP::Config->new(config => { %{ $class->config } });
    }
    return $CONFIG;
}

sub BUILD {
    my ($self) = @_;

    my @extension_stack = @{ $self->conf->available_extensions };
    my $unable_to_comply = {};

    while(my $ext = shift(@extension_stack)){
        my $class = $ext;
        Class::MOP::load_class($class);

        if($class->can('does') && $class->does('RSP::Role::AppMutation')){
            if($class->can_apply_mutations($self->conf)){
                $class->apply_mutations($self->conf);
            } else {
                push(@extension_stack, $class);
                my $tries = ++$unable_to_comply->{$class};
                if($unable_to_comply > scalar(@extension_stack)){
                    die "Unable to apply extension mutations";
                }
            }
        }
    }
}

use RSP::Transaction::Mojo;

sub handler {
  my ($self, $tx) = @_;

  my $rsptx = RSP::Transaction::Mojo->new
                                    ->request( $tx->req )
				    ->response( $tx->res );

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
