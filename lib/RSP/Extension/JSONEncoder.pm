package RSP::Extension::JSONEncoder;

use Moose;

with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use Try::Tiny;
use JSON::XS;

my $encoders = [
  JSON::XS->new->utf8,
  JSON::XS->new->utf8->pretty
];

sub bind {
    my ($self) = @_;

    $self->bind_extension({
        json => {
            encode => $self->generate_js_closure('json_encode'),
            decode => $self->generate_js_closure('json_decode'),
        },
    });
}

sub json_encode {
    my ($self, $data, $encoder) = @_;

    try {
        return $encoders->[$encoder]->encode($data);
    } catch {
        die "$_\n";
    };
}

sub json_decode {
    my ($self, $data, $encoder) = @_;

    try {
        return $encoders->[$encoder]->decode($data);
    } catch {
        die "$_\n";
    };
}

1;
