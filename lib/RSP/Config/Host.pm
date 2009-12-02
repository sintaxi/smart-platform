package RSP::Config::Host;

use Moose;
use File::Spec;
use File::Path qw(make_path);
use Try::Tiny;

has _config => (is => 'ro', required => 1, init_arg => 'config');
has _master => (is => 'ro', required => 1, init_arg => 'global_config', isa => 'RSP::Config');

has oplimit => (is => 'ro', isa => 'Int', lazy_build => 1);
sub _build_oplimit {
    my ($self) = @_;
    return $self->_config->{oplimit} ? $self->_config->{oplimit} : $self->_master->oplimit;
}

has should_report_consumption => (is => 'ro', isa => 'Bool', lazy_build => 1);
sub _build_should_report_consumption {
    my ($self) = @_;
    return $self->_config->{noconsumption} ? 0 : 1;
}

has entrypoint => (is => 'ro', isa => 'Str', default => 'main');

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

    my @parent_extensions = @{ $self->_master->extensions };
    return [@parent_extensions, @extensions];
}

has hostname => (is => 'ro', isa => 'Str', required => 1);

has actual_host => (is => 'ro', isa => 'Str', lazy_build => 1);
sub _build_actual_host {
    my ($self) = @_;
    return $self->_config->{alternate} ? $self->_config->{alternate} : $self->hostname;
}

has root => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_root {
    my ($self) = @_;
    my $hostroot = $self->_master->hostroot;
    my $dir = File::Spec->catfile($hostroot, $self->actual_host);
    if(!-e $dir){
        try {
            make_path($dir);
        } catch {
            die "Unable to create hostdirectory '$dir': $@";
        }
    }
    return $dir;
}

has code => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_code {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->root, qw(js));
    die "Code directory '$dir' does not exist" if !-d $dir;
    return $dir;
}

# XXX - make this an 'ExistantFile' type constraint?
has bootstrap_file => (is => 'ro', lazy_build => 1);
sub _build_bootstrap_file {
    my ($self) = @_;
    my $file = File::Spec->catfile($self->code, qw(bootstrap.js));
    return $file;
}

has alloc_size => (is => 'ro', lazy_build => 1, isa => 'Int');
sub _build_alloc_size {
    my ($self) = @_;
    return (1024 ** 2) * 2;
}

has log_directory => (is => 'ro', isa => 'ExistantDirectory', lazy_build => 1);
sub _build_log_directory {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->root, qw(log));
    if(!-e $dir){
        try {
            make_path($dir);
        } catch {
            die "Unable to create log directory '$dir': $@";
        }
    }
    return $dir;
}

# XXX - make this an 'ExistantFile' type constraint?
has access_log => (is => 'ro', lazy_build => 1);
sub _build_access_log {
    my ($self) = @_;
    my $logfile = File::Spec->catfile($self->log_directory, qw(access_log));
    return $logfile;
}

has web => (is => 'ro', lazy_build => 1, isa => 'ExistantDirectory');
sub _build_web {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->root, qw(web));
    die "Web directory '$dir' does not exist" if !-d $dir;
    return $dir;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
