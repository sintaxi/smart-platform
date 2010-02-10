package RSP::Config::MySQL;

use Moose;

has user => (is => 'ro', required => 1, isa => 'Str');
has password => (is => 'ro', required => 1, isa => 'Str');
has host => (is => 'ro', isa => 'Str');
has port => (is => 'ro', isa => 'Int');

1;
