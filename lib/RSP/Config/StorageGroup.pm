package RSP::Config::StorageGroup;

use Moose;

has DataStore => (is => 'ro', isa => 'Str');
has MediaStore => (is => 'ro', isa => 'Str');

1;
