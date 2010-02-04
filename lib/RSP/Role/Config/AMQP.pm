package RSP::Role::Config::AMQP;

use Moose::Role;
use RSP::Config::AMQP;

has amqp => (is => 'ro', isa => 'RSP::Config::AMQP', lazy_build => 1);
sub _build_amqp {
    my ($self) = @_;
    return RSP::Config::AMQP->new($self->_config->{amqp});
}

1;
