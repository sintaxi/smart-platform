package RSP::Extension::Sprintf;

use Moose;

with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

sub bind {
    my ($self) = @_;

    $self->bind_extension({
        'sprintf' => $self->generate_js_closure('sprintf'),
    });
}

sub sprintf {
    my ($self, $format, @args) = @_;
    return sprintf($format, @args);
}

1;
