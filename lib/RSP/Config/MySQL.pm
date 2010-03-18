package RSP::Config::MySQL;

use Moose;
use namespace::autoclean;

has user => (is => 'ro', required => 1, isa => 'Str');
has password => (is => 'ro', required => 1, isa => 'Str');
has host => (is => 'ro', isa => 'Str');
has port => (is => 'ro', isa => 'Int');

__PACKAGE__->meta->make_immutable;
1;
