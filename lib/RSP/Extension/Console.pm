package RSP::Extension::Console;

use Moose;
use namespace::autoclean;
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

__PACKAGE__->meta->make_immutable;
1;
