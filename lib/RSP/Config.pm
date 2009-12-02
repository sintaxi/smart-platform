package RSP::Config;

use Moose;
use RSP;
use Cwd qw(getcwd);

use Moose::Util::TypeConstraints;
BEGIN {
subtype 'ExistantDirectory',
    as 'Str',
    where { -d $_ },
    message { "Directory '$_' does not exist." };
}
use RSP::Config::Host;

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

has _hosts => (is => 'ro', lazy_build => 1, isa => 'HashRef');
sub _build__hosts {
    my ($self) = @_;
    
    my $hosts = {};
    my $config = $self->_config;
    for my $host (map { $_=~ /^host:(\w+)$/ ? $1 : () } keys %{$config}){
       $hosts->{$host} = $config->{"host:$host"};
    }
    return $hosts;
}

sub host {
    my ($self, $host) = @_;

    my $conf = $self->_hosts->{$host};
    die "No configuration supplied for '$host'" if !$conf;

    # XXX - MUST work out how to weaken this circular ref correctly
    my $host_conf = RSP::Config::Host->new({ config => $conf, global_config => $self, hostname => $host });
    return $host_conf;
}

# XXX - this should probably use default_oplimit in the config file, keeping it as oplimit for back-compat
has oplimit => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_oplimit {
    my ($self) = @_;
    return $self->_config->{oplimit} ? $self->_config->{oplimit} : 100_000; 
}

has hostroot => (is => 'ro', lazy_build => 1, isa => 'ExistantDirectory');
sub _build_hostroot {
    my ($self) = @_;
    my $root = $self->_config->{hostroot};

    # handle the scenario where the user uses a path relative to the RSP root
    if ( substr( $root, 0, 1 ) eq '/' ) {
        return $root;
    } else {
        $root = File::Spec->catfile( $self->root, $root);
    }
    return $root;
}



no Moose;
__PACKAGE__->meta->make_immutable;

1;
