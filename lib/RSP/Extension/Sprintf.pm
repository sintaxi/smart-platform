package RSP::Extension::Sprintf;

use Moose;
use Try::Tiny;

with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

sub bind {
    my ($self) = @_;

    $self->bind_extension({
        'sprintf' => $self->generate_js_closure('sprintf'),
    });
}

sub sprintf {
    my ($self, $format, @args) = @_;
    my $return;

    try {
        $return = sprintf($format, @args);
    } catch {
        die "$_\n";
    };

    return $return;
}

1;
