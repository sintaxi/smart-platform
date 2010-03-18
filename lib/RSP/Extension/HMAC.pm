package RSP::Extension::HMAC;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use Digest::HMAC_SHA1 qw( hmac_sha1 hmac_sha1_hex );
use Scalar::Util qw( blessed );


sub bind {
    my ($self) = @_;

    $self->bind_extension({
        digest => {
            hmac => {
                sha1 => {
                    base64 => $self->generate_js_closure('hmac_base64'),
                    'hex'  => $self->generate_js_closure('hmac_hex'),
                },
            },
        },
    });
}

sub hmac_hex {
    my ($self, $data, $key) = @_;
    return hmac_sha1_hex( _js_data($data), $key );
}

sub hmac_base64 {
    my ($self, $data, $key) = @_;
    my $dig = Digest::HMAC_SHA1->new( $key );
    $dig->add( _js_data($data) );
    return $dig->b64digest;
}

sub _js_data {
    my ($data) = @_;
    return blessed($data) ? $data->as_string : $data;
}

__PACKAGE__->meta->make_immutable;
1;
