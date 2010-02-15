package RSP::Extension::MediaStore;

use Moose;
with qw(RSP::Role::AppMutation RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

sub can_apply_mutations { 1 }
sub apply_mutations {
    my ($self, $config) = @_;

    my $config_meta = blessed($config)->meta;

    # We need Mogile config
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::MogileStorage');

    # We need local storage
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::LocalStorage');

    # We not need a way to see which was chosen
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::DataStorage');

    # We also need to know which storage to pull back for each host
    Moose::Util::apply_all_roles($config->host_class->meta, 'RSP::Role::Config::DataStorage::Host');
}

sub bind {
    my ($self) = @_;
    $self->bind_extension({
        mediastore => {
            'write' => $self->generate_js_closure('write'),
            remove => $self->generate_js_closure('remove'),
            get => $self->generate_js_closure('get'),
        },
    });

    my $class_opts;
    my $class;
    if($self->js_instance->config->storage->MediaStore eq 'Local'){
        $class = 'RSP::JSObject::MediaFile::Local';
    } elsif($self->js_instance->config->storage->MediaStore eq 'MogileFS'){
        $class = 'RSP::JSObject::MediaFile::Mogile';
    }
    
    Class::MOP::load_class($class);
    $class_opts = {
        name => 'MediaFile',
        'package' => $class,
        properties => {
            filename    => { getter => $self->generate_js_method_closure('filename') },
            mimetype    => { getter => $self->generate_js_method_closure('mimetype') },
            size        => { getter => $self->generate_js_method_closure('size') },
            'length'    => { getter => $self->generate_js_method_closure('length') },
            digest      => { getter => $self->generate_js_method_closure('digest') },
        },
        methods => {
            remove => $self->generate_js_method_closure('remove'),
        },
    };

    $self->js_instance->bind_class(%$class_opts);
}

sub DEMOLISH {
    my ($self) = @_;
    $self->js_instance->unbind_value('MediaFile');
}

has namespace => (is => 'ro', lazy_build => 1);
sub _build_namespace {
    my ($self) = @_;

    my $config = $self->js_instance->config;
    my $store_type = $config->storage->MediaStore;
    if($store_type eq 'MogileFS'){
        my $store_config = $self->config->_master->mogile;
        return RSP::Mediastore::MogileFS->new(
            trackers => $store_config->trackers,
            namespace => $config->hostname,
        );
    } elsif ($store_type eq 'Local'){
        my $store_config = $self->config->_master->local_storage;
        return RSP::Mediastore::Local->new(
            datadir => $store_config->datadir,
            namespace => $config->hostname,
        );
    } else {
        die "Unknown mediastore";
    }
}

sub write {
    my ($self, @args) = @_;
    $self->namespace->write(@args);
}

sub remove {
    my ($self, @args) = @_;
    $self->namespace->remove(@args);
}

sub get {
    my ($self, @args) = @_;
    $self->namespace->get(@args);
}

1;
