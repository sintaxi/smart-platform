package RSP::Role::Config::MogileStorage;

use Moose::Role;
use RSP::Config::MogileFS;

has mogile => (is => 'ro', isa => 'Maybe[RSP::Config::MogileFS]', lazy_build => 1);
sub _build_mogile {
    my ($self) = @_;
    if(my $conf = $self->_config->{mogilefs}){
        return RSP::Config::MogileFS->new($conf);
    }
    return;
}

1;
