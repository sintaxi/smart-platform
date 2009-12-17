package RSP::Extension::Import;

use Moose;
use Try::Tiny;

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

    my $path_to_lib = $self->js_instance->config->file(code => $lib);

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
  my $class = shift;
  my $tx    = shift;
  my $lib   = shift;
  my $path = File::Spec->catfile( RSP->config->{_}->{root}, 'library', $lib );
  if ( -e $path ) {
    return $path;
  }
  return undef;
}

1;
