package RSP::Transaction;

use strict;
use warnings;

use JavaScript;
use Module::Load qw();
use Cache::Memcached::Fast;
use Hash::Merge::Simple 'merge';
use base 'Class::Accessor::Chained';

our $HOST_CLASS = RSP->config->{_}->{host_class} || 'RSP::Host';

__PACKAGE__->mk_accessors(qw( request response runtime context hostclass ));

sub import {
  my $class = shift;
  Module::Load::load( $HOST_CLASS );
  eval {
    $class->SUPER::import(@_);
  };
}

##
## simple constructor, returns a new RSP::Transaction
##
sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
}

sub process_transaction {
  my $self = shift;

  $self->assert_transaction_ready;

  $self->bootstrap;
  $self->run;
  $self->end;
}

sub assert_transaction_ready {
  my $self = shift;
  if (!$self->request) {
    die "no request object";
  }
  
  if (!$self->response) {
    die "no response object";
  }  
}

sub cache {
  my $self = shift;

  ## if we've got a memcache, return it
  if ( $self->{cache} ) {
    return $self->{cache};
  }

  $self->{cache} = Cache::Memcached::Fast->new({  
    'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{cache}->{servers}) } ],
    'namespace'         => $self->host->hostname . ':', ## append the colon for easy reading in mcinsight...
  });
}

##
## simply sets up the basic javascript environment,
##  creates a runtime and a context, and toggles some options
##  on the two.
##
sub initialize_js_environment {
  my $self = shift;
  $self->runtime( JavaScript::Runtime->new( $self->host->alloc_size ) );
  $self->context( $self->runtime->create_context );
  $self->context->set_version( "1.8" );
  $self->context->toggle_options(qw( xml strict jit ));
}

##
## removes the context and the runtime objects, so that we don't have
##   them hanging around.
##
sub cleanup_js_environment {
  my $self = shift;
  $self->context->DESTROY;
  $self->runtime->DESTROY;
}

##
## bootstraps the javascript environment
##
sub bootstrap {
  my $self = shift;
  
  $self->initialize_js_environment;
  $self->import_extensions( $self->host->extensions );
  
  my $bs_file = $self->host->bootstrap_file;
  if (!-e $bs_file) {
    die "$!: $bs_file";
  }
  $self->context->eval_file( $bs_file );
  if ($@) {
    die $@;
  }
}

##
## this handles all the javascripty stuff
##
sub run {
  my $self = shift;  
  my $response = $self->context->call( $self->host->entrypoint, @_ );
  if ($@) {
    if (ref($@) && ref($@) eq "JavaScript::Error") {
      die "$@->{message} at $@->{fileName} line $@->{lineNumber}";
    } else {
      die $@;
    }
  } else {
    $self->encode_response( $response );
  }
}



##
## terminates the transaction
##
sub end {
  my $self = shift;
  $self->cleanup_js_environment;
}

##
## imports extensions that a host requires.  These
##   are by passing in classnames as arguments.
##
sub import_extensions {
  my $self = shift;
  my $sys  = {};
  foreach my $ext (@_) {
    eval { Module::Load::load( $ext ); };
    if (!$@) {
      if ( $ext->should_provide( $self ) ) {
        my $provided = $ext->provides( $self );
        if ( !$provided ) {
          warn "no extensions provided by $ext";
        } elsif (!ref($provided) || ref($provided) ne 'HASH') {
          warn "invalid extension provided by $ext";
        } else {
          $sys = merge $provided, $sys;
        }
      }
    } else {
      warn "couldn't load extension $ext: $@\n";
    }
  }
  $self->context->bind_value( 'system' => $sys );
}

##
## instantiates or simply returns the RSP::Host object
##
sub host {
  my $self = shift;  
  
  ## allow for more "pluggable" host classes...
  my $host_class = $self->hostclass || $HOST_CLASS;
  if ( !$self->{host} ) {
    $self->{host} = $host_class->new( $self ); 
  }
  
  return $self->{host};
}


sub log {
  my $self = shift;
  my $mesg = shift;
  print STDERR sprintf("[%s] %s\n", $self->host->hostname, $mesg);
}

1;
