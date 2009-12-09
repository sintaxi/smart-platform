package RSP::Extension::Digest;

use Moose;

use Scalar::Util qw( blessed );
use Digest::MD5 qw( md5_hex md5_base64 );
use Digest::SHA1 qw( sha1_hex sha1_base64 );

my $mapping = {
    'digest.sha1.hex' => 'digest_sha1_hex',
    'digest.sha1.base64' => 'digest_sha1_base64',
    'digest.md5.hex' => 'digest_md5_hex',
    'digest.md5.base64' => 'digest_md5_base64',
};

sub style { 'NG' }

sub provides {
    my ($self) = @_;
    return [sort keys %$mapping];
}

sub method_for {
    my ($self, $func) = @_;
    my $method = $mapping->{$func};
    if($method){
        return $method;
    }
    die "No method for function '$func'";
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

sub providing_class { __PACKAGE__ }

1;
