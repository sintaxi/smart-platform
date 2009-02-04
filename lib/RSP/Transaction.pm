package RSP::Transaction;

use strict;
use warnings;

use JavaScript;
use Module::Load qw();
use Cache::Memcached::Fast;
use Hash::Merge::Simple 'merge';

use RSP::Consumption::Ops;
use RSP::Consumption::Bandwidth;

use base 'Class::Accessor::Chained';

our $HOST_CLASS = RSP->config->{_}->{host_class} || 'RSP::Host';

__PACKAGE__->mk_accessors(qw( request response runtime context hostclass ops ));

##
## make sure we have the appropriate host class loaded
##  when we compile.
##
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

##
## process a transaction, and clean it up afterwards
##
sub process_transaction {
  my $self = shift;

  $self->assert_transaction_ready;

  $self->bootstrap;
  $self->run;
  $self->end;
}

##
## simply asserts we have all the information
##   to run a transaction.
##
sub assert_transaction_ready {
  my $self = shift;
  if (!$self->request) {
    $self->log("no request object");
    die "no request object";
  }

  if (!$self->response) {
    $self->log("no response object");
    die "no response object";
  }
}

##
## sets up the memcache for this request
##  any use of memcache that is connected via something
##  other than this method is dangerous and shouldn't be done.
##
sub cache {
  my $self = shift;
  if (ref( $self )) { ## instance method
    ## if we've got a memcache, return it
    if ( $self->{cache} ) {
      return $self->{cache};
    }

    $self->{cache} = Cache::Memcached::Fast->new({  
      'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{cache}->{servers}) } ],
      'namespace'         => $self->host->hostname . ':', ## append the colon for easy reading in mcinsight...
    });

    return $self->{cache};
  } else { ## static call
    my $hostname = shift;
    if (!$hostname) {
      $self->log("no hostname");
      die "no hostname";
    }
    ## this is from an static call, so we need to construct every time, not ideal, but we can live with it
    return Cache::Memcached::Fast->new({
      'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{cache}->{servers}) } ],
      'namespace'         => $hostname . ':', ## append the colon for easy reading in mcinsight...
    });
  }
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
  $self->runtime->set_interrupt_handler(
					sub {
					  $self->{ops}++;
					  if ( $self->ops > $self->host->op_threshold ) {
					    $self->log("op threshold exceeded");
					    die "op threshold exceeded";
					  }
					  return 1;
					}
				       );
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
  $self->import_extensions( $self->context, $self->host->extensions );

  my $bs_file = $self->host->bootstrap_file;
  if (!-e $bs_file) {
    $self->log("$!: $bs_file");
    die "$!: $bs_file";
  }
  $self->context->eval_file( $bs_file );
  if ($@) {
    $self->log($@);
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
      $self->log("$@->{message} at $@->{fileName} line $@->{lineNumber}");
      die "$@->{message} at $@->{fileName} line $@->{lineNumber}";
    } else {
      $self->log($@);
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
  $self->report_consumption;
  $self->cleanup_js_environment;
}

##
## returns the ops consumed by the transaction
##
sub ops_consumed {
  my $self = shift;
  return $self->ops;
}

##
## returns the bandwidth consumed by the transaction
##
sub bw_consumed {
  my $self = shift;
  return 0;
}

##
## writes the consumption report to the queue
##
sub report_consumption {
  my $self = shift;

  my $opreport = RSP::Consumption::Ops->new();
  $opreport->count( $self->ops_consumed );
  $opreport->host( $self->hostname );
  $opreport->uri( $self->request->url->path->to_string );

  my $bwreport = RSP::Consumption::Bandwidth->new();
  $bwreport->count( $self->bw_consumed );
  $bwreport->host( $self->hostname );
  $bwreport->uri( $self->request->url->path->to_string );

  $self->log( $opreport->as_json );
  $self->log( $bwreport->as_json );
}

##
## imports extensions that a host requires.  These
##   are by passing in classnames as arguments.
##
sub import_extensions {
  my $self = shift;
  my $cx   = shift;
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
  $cx->bind_value( 'system' => $sys );
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

##
## naive logging function that will do for now.
##
sub log {
  my $self = shift;
  my $mesg = shift;
  my ($package, $file, $line) = caller;
  print STDERR sprintf("[%s:%s:%s] %s\n", $self->host->hostname, $file, $line, $mesg);
}

1;
