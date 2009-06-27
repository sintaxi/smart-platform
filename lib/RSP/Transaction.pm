package RSP::Transaction;

use strict;
use warnings;

use JavaScript;
use RSP::Error;
use Module::Load qw();
use RSP::FakeCache;
use Cache::Memcached::Fast;
use Hash::Merge::Simple 'merge';
use Scalar::Util qw( weaken );
use RSP::Consumption::Ops;
use RSP::Consumption::Bandwidth;

use base 'Class::Accessor::Chained';

our $HOST_CLASS = RSP->config->{_}->{host_class} || 'RSP::Host';

__PACKAGE__->mk_accessors(qw( runtime context hostclass ops url ));

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
## need to implement this by hand for weak refs.
##
sub request {
  my $self = shift;
  if (@_) {
    $self->{request} = shift;
    weaken( $self->{request} );
    return $self;
  }
  return $self->{request};
}

##
## by hand for weak refs also.
##
sub response {
  my $self = shift;
  if (@_) {
    $self->{response} = shift;
    weaken( $self->{response} );
    return $self;
  }
  return $self->{response};
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
    RSP::Error->throw("no request object");
  }

  if (!$self->response) {
    $self->log("no response object");
    RSP::Error->throw("no response object");
  }
}

##
## sets up the memcache for this request
##  any use of memcache that is connected via something
##  other than this method is dangerous and shouldn't be done.
##
sub cache {
  my $self = shift;
  if (!RSP->config->{rsp}->{memcached}) { return RSP::FakeCache->new; }
  if (ref( $self )) { ## instance method
    ## if we've got a memcache, return it
    if ( $self->{cache} ) {
      return $self->{cache};
    }

    $self->{cache} = Cache::Memcached::Fast->new({  
      'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{rsp}->{memcached}) } ],
      'namespace'         => $self->host->hostname . ':', ## append the colon for easy reading in mcinsight...
    });

    return $self->{cache};
  } else { ## static call
    my $hostname = shift;
    if (!$hostname) {
      $self->log("no hostname");
      RSP::Error->throw("no hostname");
    }
    ## this is from an static call, so we need to construct every time, not ideal, but we can live with it
    return Cache::Memcached::Fast->new({
      'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{rsp}->{memcached}) } ],
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

  ## there is a faster way of doing this...
  $self->runtime->set_interrupt_handler(
					sub {
					  $self->{ops}++;
					  if ( $self->ops > $self->host->op_threshold ) {
					    $self->log("op threshold exceeded");
					    RSP::Error->throw("op threshold exceeded");
					  }
					  return 1;
					}
				       );

  $self->context( $self->runtime->create_context );
  $self->context->set_version( "1.8" );
  $self->context->toggle_options(qw( xml strict jit ));

  ## bind the error class, so that things start to work again...
  RSP::Error->bind( $self );
}

##
## removes the context and the runtime objects, so that we don't have
##   them hanging around.
##
sub cleanup_js_environment {
  my $self = shift;

  ## unset the interrupt handler
  if ( $self->runtime && $self->context ) {
    $self->runtime->set_interrupt_handler( undef );
    $self->context->unbind_value( 'system' );
  }

#  RSP::JSObject->unbind( $self->context );

  delete $self->{context};
  delete $self->{runtime};
#  $self->context->DESTROY;
#  $self->runtime->DESTROY;
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
    RSP::Error->throw("$!: $bs_file");
  }
  my $result = $self->context->eval_file( $bs_file );
  if ($@) {
    $self->log($@);
    my $err = RSP::Error->new( $@, $self );
    $err->throw;

  }
}

##
## extension_name provides details for the RSP::Error class
##
sub extension_name {
  return "compilation stage";
}

##
## builds arguments for the entrypoint, by default these are empty.
## the HTTP binding should provide the HTTP request, the async binding
## should provide the async request, etc, etc.
##
sub build_entrypoint_arguments {
  return ();
}

##
## this handles all the javascripty stuff
##
sub run {
  my $self = shift;
  my $response = eval {
    $self->context->call(
			 $self->host->entrypoint,
			 $self->build_entrypoint_arguments
			);
  };
  if ($@) {
    $self->log($@);
    if (ref($@) && ref($@) eq "JavaScript::Error") {
      RSP::Error->throw( $@ );
    } elsif ( $@ =~ /Undefined subroutine/ ) {
      my $err = RSP::Error->new("Could not call function " . $self->host->entrypoint);
      $err->{fileName} = undef;
      $err->{lineNumber} = undef;
      $err->throw;
    } else {
      $@ =~ s/ at (.+)\sline\s(\d+)\.$//;
      my $err = RSP::Error->new( $@ );
      $err->{lineNumber} = undef;
      $err->{fileName} = undef;
      throw $err;
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
  my $post_callback = shift;

  $self->report_consumption;
  undef( $self->{cache} );
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

  return unless $self->host->should_report_consumption;

  my @reports = ();

  my $opreport = RSP::Consumption::Ops->new();
  $opreport->count( $self->ops_consumed );
  $opreport->host( $self->hostname );
  $opreport->uri( $self->url );
  push @reports, $opreport;

  ## the callback has to do it in the case of
  ## chunked responses...
  if ( $self->response && $self->request ) {
    my $bwreport = RSP::Consumption::Bandwidth->new();
    $bwreport->count( $self->bw_consumed );
    $bwreport->host( $self->hostname );
    $bwreport->uri( $self->url );
    push @reports, $bwreport;
  }

  $self->consumption_log( @reports );
}

sub consumption_log {
  my $self = shift;
  if ( RSP->config->{stomp} ) {
    require RSP::Stomp;
    RSP::Stomp->report( @_ );
  } else {
    foreach my $report (@_ ) {
      $self->log( $report->as_json );
    }
  }
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
    my $ext_class = $ext->providing_class;
    if (!$@) {
      if ( $ext_class->should_provide( $self ) ) {
        my $provided = $ext_class->provides( $self );
        if ( !$provided ) {
	  ## perhaps we should do something?
        } elsif (!ref($provided) || ref($provided) ne 'HASH') {
          #warn "invalid extension provided by $ext";
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

  $mesg = sprintf($mesg, @_);
  my ($package, $file, $line) = caller;
  print STDERR sprintf("[%s:%s:%s:%s] %s\n", $$, $self->host->hostname, $file, $line, $mesg);
}

1;
