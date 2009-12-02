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


no Moose;
__PACKAGE__->meta->make_immutable;

1;
