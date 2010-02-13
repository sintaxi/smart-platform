package RSP::Config::MogileFS;

use Moose;

has _trackers_string => (is => 'ro', isa => 'Str', required => 1, init_arg => 'trackers');
has trackers => (is => 'ro', isa => 'ArrayRef', lazy_build => 1);
sub _build_tackers {
    my ($self) = @_;
    return [ split(',', $self->_trackers_string) ];
}

1;
