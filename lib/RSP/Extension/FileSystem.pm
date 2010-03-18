package RSP::Extension::FileSystem;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use RSP::JSObject::File;

sub bind {
    my ($self) = @_;

    my $opts = {
        name => $self->jsclass,
        package => $self->bind_class,
        properties => $self->properties,
        methods => $self->methods,
        constructor => $self->generate_js_method_closure('new'),
    };

    $self->js_instance->bind_class(%$opts);

    $self->bind_extension({
        filesystem => {
            get => $self->generate_js_closure('get_file'),
        }
    });
}

sub jsclass { 'File' }
sub bind_class { 'RSP::JSObject::File' }

sub properties {
    my ($self) = @_;

    return {
        contents    => { getter => $self->generate_js_method_closure('as_string') },
        filename    => { getter => $self->generate_js_method_closure('filename') },
        mimetype    => { getter => $self->generate_js_method_closure('mimetype') },
        size        => { getter => $self->generate_js_method_closure('size') },
        'length'    => { getter => $self->generate_js_method_closure('size') },
        mtime       => { getter => $self->generate_js_method_closure('mtime') },
        'exists'    => { getter => $self->generate_js_method_closure('exists') },
    };
}

sub methods {
    my ($self) = @_;

    return { toString => $self->generate_js_method_closure('filename') };
}

sub get_file {
    my ($self, $path) = @_;

    my $real_path = $self->js_instance->config->file(web => $path);
    if( -f $real_path ){
        return RSP::JSObject::File->new($real_path, $path);
    } else {
        local $SIG{__DIE__};
        die "couldn't open file $path: $!\n";
    }
}

__PACKAGE__->meta->make_immutable;
1;
