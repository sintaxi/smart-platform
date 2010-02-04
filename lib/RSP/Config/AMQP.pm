package RSP::Config::AMQP;

use Moose;

has user => (is => 'ro', required => 1, isa => 'Str');
has pass => (is => 'ro', required => 1, isa => 'Str');
has host => (is => 'ro', required => 1, isa => 'Str');
has port => (is => 'ro', isa => 'Int', default => 5672);
has vhost => (is => 'ro', isa => 'Str', default => '/');
has repository_management_exchange => (is => 'ro', required => 1, isa => 'Str');

1;
