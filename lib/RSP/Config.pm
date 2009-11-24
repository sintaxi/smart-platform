package RSP::Config;

use Moose;
use RSP;
use Cwd qw(getcwd);

use Moose::Util::TypeConstraints;

subtype 'ExistantDirectory',
    as 'Str',
    where { -d $_ },
    message { "Directory '$_' does not exist." };

has _config => (is => 'ro', lazy_build => 1, isa => 'HashRef', init_arg => 'config');
sub _build__config {
    return RSP->config->{_};
}

has root => (is => 'ro', lazy_build => 1, isa => 'ExistantDirectory');
sub _build_root {
    my ($self) = @_;
    my $root = $self->_config->{root} // getcwd();
    return $root;
}

has extensions => (is => 'ro', lazy_build => 1, isa => 'ArrayRef[ClassName]');
sub _build_extensions {
    my ($self) = @_;
    my $extensions_string = $self->_config->{extensions};
    my @extensions = map {
            'RSP::Extension::' .  $_;
        } split(/,/, $extensions_string);

    for my $class (@extensions){
        eval { Class::MOP::load_class($class) };
        die "Could not load extension '$class': $@" if $@;
    }

    return [@extensions];
}

has server => (is => 'ro', lazy_build => 1, isa => 'RSP::Config::Server');
sub _build_server {
    my ($self) = @_;
    my $server_conf = $self->_config->{server};
   
    my $server = RSP::Config::Server->new(config => $server_conf);
    return $server;
}

package RSP::Config::Server;

use Moose;
use File::Spec;

has _config => (is => 'ro', required => 1, init_arg => 'config');

has root => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_root {
    my ($self) = @_;
    return $self->_config->{Root};
}

has pidfile => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_pidfile {
    my ($self) = @_;
    my $root = $self->root;

    my $run_dir = File::Spec->catfile($root, qw(run));
    if(!-d $run_dir){
        die "Could not locate run directory '$run_dir' for pidfile: $!";
    }

    return File::Spec->catfile($run_dir, qw(rsp.pid));
}

has connection_timeout => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_connection_timeout {
    my ($self) = @_;
    return (exists $self->_config->{ConnectionTimeout}) ?
        $self->_config->{ConnectionTimeout} : 120;
}

has max_requests_per_client => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_max_requests_per_client {
    my ($self) = @_;
    return (exists $self->_config->{MaxRequestsPerClient}) ?
        $self->_config->{MaxRequestsPerClient} : 5;
}

has user => (is => 'ro', isa => 'Maybe[Str]', lazy_build => 1);
sub _build_user {
    my ($self) = @_;
    my $user = (exists $self->_config->{User}) ? $self->_config->{User} : undef;
    # XXX - if the user has been set we should probably verify they exist, etc.
    return $user;
}

has group => (is => 'ro', isa => 'Maybe[Str]', lazy_build => 1);
sub _build_group {
    my ($self) = @_;
    my $group = (exists $self->_config->{Group}) ? $self->_config->{Group} : undef;
    # XXX - if the group has been set we should probably verify it exists, etc.
    return $group;
}

has max_children => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_max_children {
    my ($self) = @_;
    return (exists $self->_config->{MaxClients}) ? $self->_config->{MaxClients} : 5;
}

has max_requests_per_child => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_max_requests_per_child {
    my ($self) = @_;
    return (exists $self->_config->{MaxRequestsPerChild}) ?
        $self->_config->{MaxRequestsPerChild} : 5;
}

1;
