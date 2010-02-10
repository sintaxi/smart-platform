package RSP::Extension::DataStore;

use Moose;
with qw(RSP::Role::AppMutation RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use RSP::Datastore::SQLite;

sub can_apply_mutations { 1 }
sub apply_mutations {
    my ($self, $config) = @_;

    my $config_meta = blessed($config)->meta;

    # We need MySQL configuration
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::MySQLStorage');

    # We also need SQLite config for LocalStorage
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::LocalStorage');

    # We now need an way to see which one was chosen
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::DataStorage');

    # We also need to know which storage to pull back for each host
    Moose::Util::apply_all_roles($config->host_class->meta, 'RSP::Role::Config::DataStorage::Host');
}

sub bind {
    my ($self) = @_;
    $self->bind_extension({
        datastore => {
            get => $self->generate_js_closure('get'),
            remove => $self->generate_js_closure('remove'),
            search => $self->generate_js_closure('search'),
            'write' => $self->generate_js_closure('write'),
        },
    });
}

has namespace => (is => 'ro', lazy_build => 1);
sub _build_namespace {
    my ($self) = @_;
    return $self->_get_backend;
}

sub _get_backend {
    my ($self) = @_;

    my $config = $self->js_instance->config;

    my $store_type = $config->storage->DataStore;
    if($store_type eq 'MySQL'){
        my $store_config = $config->_master->mysql;
    } elsif ($store_type eq 'SQLite'){
        my $store_config = $config->_master->local_storage;
        return RSP::Datastore::SQLite->new(
            namespace => $config->hostname,
            datadir => $store_config->datadir,
        );
    } else {
        die "Unknown datastore";
    }
}


sub get {
    my ($self, $type, @args) = @_;
    return $self->namespace->read( lc($type), @args );
}

sub search {
    my ($self, $type, @args) = @_;
    return $self->namespace->query( lc($type), @args );
}

sub remove {
    my ($self, $type, @args) = @_;
    return $self->namespace->remove( lc($type), @args );
}

sub write {
    my ($self, $type, @args) = @_;
    return $self->namespace->write( lc($type), @args );
}

1;
