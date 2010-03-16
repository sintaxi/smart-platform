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
    my ($self, $lib) = @_;

    my $name = $lib;
    $lib =~ s{\.}{/}g;
    $lib .= '.js';
    
    # Ensure applications are unable to leave their sandbox
    # XXX - this is probably overkill since users don't use paths directly, but it's better safe than
    # sorry
    ($lib) = File::Spec->no_upwards($lib);
    
    my @paths;
    if($lib =~ m{\*}){
        my $code_dir = $self->js_instance->config->code;
        my $try = File::Spec->catfile($code_dir, $lib);
        @paths = glob($try);
    } else {
        push @paths, $self->js_instance->config->file(code => $lib);
    }

    for my $path_to_lib (@paths) {
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
}

1;
