package RSP::Config::MogileFS;

use Moose;
use namespace::autoclean;

has _trackers_string => (is => 'ro', isa => 'Str', required => 1, init_arg => 'trackers');
has trackers => (is => 'ro', isa => 'ArrayRef', lazy_build => 1, init_arg => undef);
sub _build_trackers {
    my ($self) = @_;
    return [ split(',', $self->_trackers_string) ];
}

__PACKAGE__->meta->make_immutable;
1;
