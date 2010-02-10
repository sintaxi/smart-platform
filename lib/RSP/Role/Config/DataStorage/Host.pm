package RSP::Role::Config::DataStorage::Host;
use Moose::Role;

has storage => (is => 'ro', isa => 'RSP::Config::StorageGroup', lazy_build => 1);
sub _build_storage {
    my ($self) = @_;

    if(my $lookup = $self->_config->{storage}){
        $lookup =~ s/^storage://;
        return $self->_master->data_storage_groups->{$lookup};
    }

    return $self->_master->storage;
}

1;
