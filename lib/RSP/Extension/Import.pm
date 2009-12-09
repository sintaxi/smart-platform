package RSP::Extension::Import;

use Moose;
use Try::Tiny;

sub provides {
    [qw(use)];
}

sub method_for {
    my ($self, $func) = @_;
    if($func eq 'use'){
        return 'use';
    }
    die "No method for function '$func'";
}

sub style { 'NG' }

# XXX TODO - should this be weakened?
has js_instance => (is => 'ro', isa => 'Object', required => 1);

sub use {
    my ($self, $lib) = @_;

    my $name = $lib;
    $lib =~ s{\.}{/}g;
    $lib .= '.js';

    my $path_to_lib = $self->js_instance->config->file(code => $lib);

    if(!-e $path_to_lib){
        die "Library '$name' does not exist";
    }

    try {
        $self->js_instance->evaluate_file($path_to_lib);
        die $@ if $@;
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

sub providing_class { __PACKAGE__ }

1;
