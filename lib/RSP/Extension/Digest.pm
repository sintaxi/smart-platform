package RSP::Extension::Digest;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use Scalar::Util qw( blessed );
use Digest::MD5 qw( md5_hex md5_base64 );
use Digest::SHA1 qw( sha1_hex sha1_base64 );

sub bind {
    my ($self) = @_;
    $self->bind_extension({
        digest => {
            sha1 => {
                'hex' => $self->generate_js_closure('digest_sha1_hex'),
                base64 => $self->generate_js_closure('digest_sha1_base64'),
            },
            md5 => {
                'hex' => $self->generate_js_closure('digest_md5_hex'),
                base64 => $self->generate_js_closure('digest_md5_base64'),
            },
        }, 
    });
}

sub _js_data {
    my ($data) = @_;
    return blessed($data) ? $data->as_string : $data;
}

sub digest_sha1_hex {
    my ($self, $data) = @_;
    return sha1_hex( _js_data($data) );
}

sub digest_sha1_base64 {
    my ($self, $data) = @_;
    return sha1_base64( _js_data($data) );
}

sub digest_md5_hex {
    my ($self, $data) = @_;
    return md5_hex( _js_data($data) );
}

sub digest_md5_base64 {
    my ($self, $data) = @_;
    return md5_base64( _js_data($data) );
}

__PACKAGE__->meta->make_immutable;
1;
