package RSP::Extension::Import;

use Moose;
use Try::Tiny;
use File::Spec;

with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

sub bind {
    my ($self) = @_;

    my $use_closure = $self->generate_js_closure('use');
    $self->bind_extension({
       use => $use_closure, 
    });
}

sub use {
    my ($self, $lib, $version) = @_;

    my $name = $lib;
    $lib =~ s{\.}{/}g;
    $lib .= '.js';

    my $path_to_lib;

    if(!$version){
        $path_to_lib = $self->js_instance->config->file(code => $lib);
    } else {
        $path_to_lib = $self->global_lib($name, $version);
    }


    local $SIG{__DIE__};
    if(!-e $path_to_lib){
        die "Library '$name' does not exist\n";
    }

    try {
        $self->js_instance->evaluate_file($path_to_lib);
        die "$@\n" if $@;
    } catch {
        #$self->js_instance->config->log($_);
        die "Unable to load library '$name': $_";
    };
}

sub global_lib {
    my ($self, $lib, $version) = @_;

    my $name = $lib;

    my $versioned_lib_dir = File::Spec->catdir(
        $self->js_instance->config->global_library,
        $name . "_" . $version
    );

    if ( -e $versioned_lib_dir ) {
        $lib =~ s{\.}{/}g;
        $lib .= '.js';
        return File::Spec->catdir($versioned_lib_dir, $lib);
    }

    local $SIG{__DIE__};
    die qq{Library name '$name' at version '$version' does not exist};
}

1;
