package RSP::Role::Config::LocalStorage;

use Moose::Role;
use RSP::Config::LocalStorage;

has local_storage => (is => 'ro', isa => 'Maybe[RSP::Config::LocalStorage]', lazy_build => 1);
sub _build_local_storage {
    my ($self) = @_;
    if(my $conf = $self->_config->{localstorage}){
        return RSP::Config::LocalStorage->new(datadir => $conf->{data});
    }
    return;
}

1;
