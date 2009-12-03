package RSP::Role::Config::SpiderMonkey::Host;

use Moose::Role;

requires 'js_engine';

has use_e4x => (is => 'ro', isa => 'Bool', lazy_build => 1);
sub _build_use_e4x {
    my ($self) = @_;

    return exists $self->_config->{use_e4x} ? $self->_config->{use_e4x} : $self->_master->use_e4x;
}

has use_strict => (is => 'ro', isa => 'Bool', lazy_build => 1);
sub _build_use_strict {
    my ($self) = @_;

    return exists $self->_config->{use_strict} ? $self->_config->{use_strict} : $self->_master->use_strict;
}

1;
