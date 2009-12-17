package RSP::Extension::Console;

use Moose;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

sub bind {
    my ($self) = @_;
    $self->bind_extension({
        console => { 'log' => $self->generate_js_closure('console_log'), },
    });
}

sub console_log {
    my ($self, $msg) = @_;
    print STDERR $msg;
}

1;
