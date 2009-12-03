package RSP::Role::Config::SpiderMonkey;

use Moose::Role;

has use_e4x => (is => 'ro', isa => 'Bool', lazy_build => 1);
sub _build_use_e4x {
    my ($self) = @_;

    return exists $self->_config->{_}{spidermonkey_use_e4x} ? $self->_config->{_}{spidermonkey_use_e4x} : 1;
}

has use_strict => (is => 'ro', isa => 'Bool', lazy_build => 1);
sub _build_use_strict {
    my ($self) = @_;

    return exists $self->_config->{_}{spidermonkey_use_strict} ? $self->_config->{_}{spidermonkey_use_strict} : 1;
}

1;
