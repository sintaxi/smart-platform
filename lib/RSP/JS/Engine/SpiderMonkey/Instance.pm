package RSP::JS::Engine::SpiderMonkey::Instance;

use Moose;
use JavaScript;
use Hash::Merge::Simple qw(merge);
use Try::Tiny;
use Scalar::Util qw(reftype);

has runtime => (
    is => 'ro', isa => 'JavaScript::Runtime', lazy_build => 1, 
    handles => [qw(set_interrupt_handler create_context)],
    clearer => 'clear_runtime',
    predicate => 'has_runtime',
);
sub _build_runtime {
    my ($self) = @_;
    my $runtime = JavaScript::Runtime->new( $self->alloc_size );
    return $runtime;
}

has context => (
    is => 'ro', isa => 'JavaScript::Context', lazy_build => 1,
    handles => {
        set_version             => 'set_version',
        options                 => 'toggle_options',
        bind_value              => 'bind_value',
        evaluate_file           => 'eval_file',
        call                    => 'call',
        unbind_value            => 'unbind_value',
        bind_class              => 'bind_class',
        bind_function           => 'bind_function',
        'eval'                  => 'eval',
        set_pending_exception   => 'set_pending_exception',
    },
    clearer => 'clear_context',
    predicate => 'has_context',
);
sub _build_context {
    my ($self) = @_;
    return $self->create_context;
}

has config => (
    is => 'ro', isa => 'Object', required => 1, 
    handles => {
        _initial_interrupt_handler => 'interrupt_handler',
        extensions => 'extensions',
        bootstrap_file => 'bootstrap_file',
        hostname => 'hostname',
        entrypoint => 'entrypoint',
        strict_enabled => 'use_strict',
        e4x_enabled => 'use_e4x',
        alloc_size => 'alloc_size',
    },
);

has interrupt_handler => (is => 'rw', isa => 'Maybe[CodeRef]', trigger => \&_trigger_interrupt_handler, lazy_build => 1);
sub _build_interrupt_handler {
    my ($self) = @_;
    return $self->_initial_interrupt_handler;
}
sub _trigger_interrupt_handler {
    my ($self, $value, $old_value) = @_;
    $self->set_interrupt_handler($value);
}

has version => (is => 'rw', isa => 'Str', trigger => \&_trigger_version, default => "1.8");
sub _trigger_version {
    my ($self, $value, $old_value) = @_;
    $self->set_version($value);
}

around options => sub {
    my $orig = shift;
    my $self = shift;

    my @opts = (
        $self->strict_enabled ? 'strict' : (),
        $self->e4x_enabled ? 'e4x' : (),
    ); 
    $orig->($self, sort @opts);
};

sub BUILD {
    my ($self) = @_;
    $self->version($self->version);
    $self->options($self->options);
    $self->interrupt_handler($self->interrupt_handler);
    $self->_import_extensions;
}

sub _import_extensions {
    my $self = shift;
    my $sys  = {};

    $self->bind_value('recur', sub {});
    my $bootstrap = <<EOJS;
(function(){
    var merge_recursively = function (obj1, obj2) {
      for (var p in obj2) {
        try {
          // Property in destination object set; update its value.
          if ( typeof obj2[p] == 'object' ) {
            if( obj2[p] instanceof PerlSub ){
                obj1[p] = obj2[p]; 
            } else {
                obj1[p] = merge_recursively(obj1[p], obj2[p]);
            }
          } else {
            obj1[p] = obj2[p];
          }
        } catch(e) {
          // Property in destination object not set; create it and set its value.
          obj1[p] = obj2[p];
        }
      }
      return obj1;
    }

    recur = merge_recursively;
})();
EOJS

    $self->bind_value('extensions', {});
    foreach my $ext (@{ $self->extensions }) {
        if($ext->can('does') && $ext->does('RSP::Role::Extension')){
            my $ext_obj = $ext->new({ js_instance => $self });
            $ext_obj->bind;
        }
    }
    
    try {
        $self->eval($bootstrap);
        $self->bind_value('system', {});

        $self->eval("
            (function(){
                for(var x in extensions){
                    system = recur(system, extensions[x]);
                }
            })();
        ");

        $self->unbind_value('recur');
        $self->unbind_value('extensions');

        die $@ if $@;
    } catch {
        die "unable to bind 'system': $_";
    };
}

sub _bootstrap {
    my ($self) = @_;

    my $bs_file = $self->bootstrap_file;
    if (!-e $bs_file) {
      die "bootstrap file '$bs_file' does not exist for host '" . $self->hostname. "': $!";
    }

    try {
        my $return = $self->evaluate_file( $bs_file );
        die $@ if $@;
    } catch {
        die "Could not evaluate bootstrap file '$bs_file': $_";
    };
}

sub initialize {
    my ($self) = @_;
    $self->_bootstrap;
}

sub run {
    my ($self, @args) = @_;

    my $entrypoint = $self->entrypoint;
    my $arguments = [];
    if(@args){
        if(scalar(@args) == 2){
            ($entrypoint, $arguments) = @args;
        } elsif(scalar(@args) == 1) {
            ($arguments) = @args;
        }
    }

    die "Arguments for run() must be in an ArrayRef" if (!(reftype($arguments) eq 'ARRAY'));

    my $return_value;
    try {
        $return_value = $self->call( $entrypoint, @{ $arguments });
        die $@ if $@;
    } catch {
        die "Could not call function '$entrypoint': $_";
    };
    return $return_value;
}

sub DEMOLISH {
    my ($self) = @_;
    
    if($self->has_context && $self->has_runtime){
        $self->interrupt_handler(undef);
        $self->unbind_value('system');
    }

    # is this even needed ?
    $self->clear_context;
    $self->clear_runtime;
}

1;
