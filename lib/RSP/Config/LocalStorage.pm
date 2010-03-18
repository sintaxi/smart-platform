package RSP::Config::LocalStorage;

use Moose;
use namespace::autoclean;

has datadir => (is => 'ro', isa => 'Str', required => 1);

__PACKAGE__->meta->make_immutable;
1;
