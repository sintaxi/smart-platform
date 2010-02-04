package RSP::Role::Config::AMQP::Host;

use Moose::Role;
sub amqp {
    my ($self) = @_;
    return $self->_master->amqp;
}

1;
