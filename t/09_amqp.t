use strict;
use warnings;

use Test::More tests => 21;
use mocked [qw(Net::RabbitMQ t/Mock)];

basic: {
    use_ok('RSP::AMQP');

    my $amqp = RSP::AMQP->new(user => 'bob', pass => 'sekret');
    isa_ok($amqp, 'RSP::AMQP');

    is($amqp->user, 'bob', q{user is correct});
    is($amqp->pass, 'sekret', q{pass is correct});
    is($amqp->host, 'localhost', q{default host is correct});
    is($amqp->port, 5672, q{default port is correct});
    is($amqp->vhost, '/', q{default vhost is correct});
    is($amqp->channel, 1, q{default channel is correct});
}

send_to_exchange: {
    use_ok('RSP::AMQP');

    my $amqp = RSP::AMQP->new(user => 'bob', pass => 'sekret', host => 'foo', port => '2020', vhost => '/foo', channel => 2);
    isa_ok($amqp, 'RSP::AMQP');

    is($amqp->user, 'bob', q{user is correct});
    is($amqp->pass, 'sekret', q{pass is correct});
    is($amqp->host, 'foo', q{host is correct});
    is($amqp->port, 2020, q{port is correct});
    is($amqp->vhost, '/foo', q{vhost is correct});
    is($amqp->channel, 2, q{channel is correct});

    $amqp->send(some_exchange => 'howdy');
    is_deeply(
        $Net::RabbitMQ::CONNECT_DETAILS,
        { user => 'bob', password => 'sekret', port => 2020, host => 'foo', vhost => '/foo', },
        q{connection details are correct}
    );
    is($Net::RabbitMQ::CURRENT_CHANNEL, 2, q{opened channel is correct});
    is_deeply(
        $Net::RabbitMQ::PUBLISHED,
        { channel => 2, route_key => 'some_exchange', msg => 'howdy', exchange => 'some_exchange' },
        q{published details are correct}
    );

    undef($amqp);
    is($Net::RabbitMQ::LAST_CHANNEL_CLOSED, 2, q{channel is closed on destroy});
    is($Net::RabbitMQ::DISCONNECTED, 1, q{connection is closed on destroy});
}

