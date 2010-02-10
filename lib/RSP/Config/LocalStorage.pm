package RSP::Config::LocalStorage;

use Moose;

has datadir => (is => 'ro', isa => 'Str', required => 1);

1;
