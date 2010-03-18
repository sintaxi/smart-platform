package RSP::Extension::Gitosis;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::AppMutation RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

sub can_apply_mutations {
    my ($class, $config) = @_;

    return 1;
}

sub apply_mutations {
    my ($self, $config) = @_;

    # We require AMQP!
    my $config_meta = blessed($config)->meta;
    Moose::Util::apply_all_roles($config_meta, 'RSP::Role::Config::AMQP');
    
    my $host_meta = $config->host_class->meta;
    Moose::Util::apply_all_roles($host_meta, 'RSP::Role::Config::AMQP::Host');
}


use File::Temp;
use JSON::XS;
use RSP::AMQP;

sub bind {
    my ($self) = @_;
    $self->bind_extension({
        gitosis => {
            repo => {
                clone => $self->generate_js_closure('clone'),
                'delete' => $self->generate_js_closure('delete_repo'),
            },
            key => {
                'write' => $self->generate_js_closure('write_key'),
                'exists' => $self->generate_js_closure('check_key'),
            },
        },
    });
}

sub write_key {
  my $self = shift;
  my $user = shift;
  my $key  = shift;

    my $mesg = {
        user => $user,
        key => $key,
    };

    my $conf = $self->js_instance->config->amqp;
    my $amqp = $self->_new_amqp_instance;
    $amqp->send(
        $conf->repository_key_registration_exchange,
        encode_json( $mesg )
    );
    return 1;
}

sub check_key {
  my $self = shift;
  my $user = shift;

  my $keyfile = File::Spec->catfile(
				    RSP->config->{gitosis}->{admin},
				    'keydir',
				    sprintf('%s.pub', $user)
				   );
  -e $keyfile
}

sub clone {
    my ($self, $from, $to) = @_;
    
    my $mesg = {
        from_project => $from,
        to_project   => $to
    };

    my $conf = $self->js_instance->config->amqp;
    my $amqp = $self->_new_amqp_instance;
    $amqp->send(
        $conf->repository_management_exchange,
        encode_json( $mesg )
    );
    return 1;
}

sub delete_repo {
    my ($self, $repo) = @_;
    
    my $mesg = { repo => $repo };
    
    my $conf = $self->js_instance->config->amqp;
    my $amqp = $self->_new_amqp_instance;
    $amqp->send(
        $conf->repository_deletion_exchange,
        encode_json( $mesg )
    );
    return 1;
}

sub _new_amqp_instance {
    my ($self) = @_;
    my $conf = $self->js_instance->config->amqp;
    my $amqp = RSP::AMQP->new(
        user => $conf->user, 
        pass => $conf->pass,
        ($conf->host ? (host => $conf->host) : ()),
        ($conf->port ? (port => $conf->port) : ()),
        ($conf->vhost ? (vhost => $conf->vhost) : ()),
    );
    return $amqp;
}

__PACKAGE__->meta->make_immutable;
1;
