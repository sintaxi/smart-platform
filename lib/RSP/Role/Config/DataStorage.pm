package RSP::Role::Config::DataStorage;
use Moose::Role;

use RSP::Config::StorageGroup;

has data_storage_groups => (is => 'ro', isa => 'HashRef', lazy_build => 1);
sub _build_data_storage_groups {
    my ($self) = @_;

    my $groups = {};
    for my $key (keys %{ $self->_config }){
        if(my ($name) = $key =~ qr{^storage:(.+)$}){
            $groups->{$name} = RSP::Config::StorageGroup->new($self->_config->{$key});
        }
    }

    return $groups;
}

has storage => (is => 'ro', isa => 'RSP::Config::StorageGroup', lazy_build => 1);
sub _build_storage {
    my ($self) = @_;

    my $lookup = $self->_config->{rsp}{storage};
    die "No storage identifier supplied in [rsp] block" if !$lookup;

    $lookup =~ s/^storage://;
    return $self->data_storage_groups->{$lookup};
}

1;
