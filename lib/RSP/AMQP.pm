package RSP::AMQP;

use Moose;
use namespace::autoclean;
use Net::RabbitMQ;

has host => (is => 'rw', isa => 'Str', default => 'localhost');
has port => (is => 'rw', isa => 'Int', default => 5672);
has user => (is => 'rw', isa => 'Str', required => 1);
has pass => (is => 'rw', isa => 'Str', required => 1);
has vhost => (is => 'rw', isa => 'Str', default => '/');
has channel => (is => 'ro', isa => 'Int', default => 1, required => 1);

has _mq => (is => 'rw', isa => 'Net::RabbitMQ', lazy_build => 1);
sub _build__mq {
    my ($self) = @_;
    my $mq = Net::RabbitMQ->new;
    $mq->connect($self->host, {
        user => $self->user, password => $self->pass, port => $self->port, vhost => $self->vhost
    });
    $mq->channel_open($self->channel);
    return $mq;
}

sub send {
    my ($self, $queuename, $msg_str) = @_;
    $self->_mq->publish($self->channel, $queuename, $msg_str, { exchange => $queuename });
}

sub DEMOLISH {
    my ($self) = @_;
    $self->_mq->channel_close($self->channel);
    $self->_mq->disconnect;
}

__PACKAGE__->meta->make_immutable;
1;
