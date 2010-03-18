package RSP::Config::StorageGroup;

use Moose;
use namespace::autoclean;

has DataStore => (is => 'ro', isa => 'Str');
has MediaStore => (is => 'ro', isa => 'Str');

__PACKAGE__->meta->make_immutable;
1;
