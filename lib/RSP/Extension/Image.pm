package RSP::Extension::Image;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use RSP::JSObject::Image;

sub bind {
    my ($self) = @_;

    my $opts  = {
        name       => $self->jsclass,
        package    => $self->bind_class,
        properties => $self->properties,
        methods    => $self->methods,
        constructor => $self->generate_js_method_closure('new')
    };

    $self->js_instance->bind_class( %$opts );
}

sub jsclass { 'Image' }

sub bind_class { 'RSP::JSObject::Image' }

sub properties {
    my ($self) = @_;

    return {
        width  => { getter => $self->generate_js_method_closure('get_width')  },
        height => { getter => $self->generate_js_method_closure('get_height') },
    };
}

sub methods {
    my ($self) = @_;
    
    return {
        flip_horizontal => $self->generate_js_method_closure('flip_horizontal'),
        flip_vertical   => $self->generate_js_method_closure('flip_vertical'),
        rotate          => $self->generate_js_method_closure('rotate'),
        scale           => $self->generate_js_method_closure('scale'),
        crop            => $self->generate_js_method_closure('crop'),
        save            => $self->generate_js_method_closure('save'),
    };
}

sub DEMOLISH {
    my ($self) = @_;
    $self->js_instance->unbind_value( $self->jsclass );
}

__PACKAGE__->meta->make_immutable;
1;
