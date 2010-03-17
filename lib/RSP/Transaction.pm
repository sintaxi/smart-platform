package RSP::Transaction;

use strict;
use warnings;

use JavaScript;
use RSP;
use RSP::FakeCache;
use Cache::Memcached::Fast;
use Hash::Merge::Simple 'merge';
use Scalar::Util qw( weaken );
use RSP::Consumption::Ops;
use RSP::Consumption::Bandwidth;

use feature qw(switch);
use Class::MOP; # for load_class
use Try::Tiny;
use Scalar::Util qw(blessed);

use base 'Class::Accessor::Chained';

#our $HOST_CLASS = RSP->config->{_}->{host_class} || 'RSP::Host';

__PACKAGE__->mk_accessors(qw( runtime context hostclass ops url has_exceeded_ops ));

##
## make sure we have the appropriate host class loaded
##  when we compile.
##
sub import {
  my $class = shift;
  eval {
    $class->SUPER::import(@_);
  };
}

sub config {
    return RSP->conf;
}

##
## simple constructor, returns a new RSP::Transaction
##
sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->_load_js_engines;

  return $self;
}

# XXX - Currently we only support Spidermonkey
# These should really be loaded as Extensions, but for now, we'll do it explicitly
my $js_engine_objs = {};
my @js_engines = qw(SpiderMonkey);
sub _load_js_engines {
    my ($self) = @_;
    for my $engine (@js_engines) {
        my $engine_class = "RSP::JS::Engine::$engine";
        try {
            Class::MOP::load_class($engine_class);
        } catch {
            die "Could not load class '$engine_class' for JS engine '$engine': $_";
        };

        # Initialize the engine so that we can get configuration settings for this
        # engine available
        my $engine_obj = $engine_class->new;
        $engine_obj->initialize;

        $js_engine_objs->{ $engine } = $engine_obj;
    }

    return 1;
}

sub fetch_js_engine {
    my ($self, $engine) = @_;
    my $obj = $js_engine_objs->{$engine};

    die "No such JS Engine '$engine' loaded" if !$obj;
    return $obj;
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
    $self->config->error("no request object");
    die "no request object";
  }

  if (!$self->response) {
    $self->config->error("no response object");
    die "no response object";
  }
}

##
## sets up the memcache for this request
##  any use of memcache that is connected via something
##  other than this method is dangerous and shouldn't be done.
##
my $CLASS_CACHE_OBJ;
sub cache {
  my $self = shift;
  if (!RSP->config->{rsp}->{memcached}) { return RSP::FakeCache->new; }
  my $obj;
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
      die "no hostname";
    }
    ## this is from an static call, so we need to construct every time, not ideal, but we can live with it
    $CLASS_CACHE_OBJ ||= do {
        Cache::Memcached::Fast->new({
            'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{rsp}->{memcached}) } ],
            'namespace'         => $hostname . ':', ## append the colon for easy reading in mcinsight...
        });
    };
    $obj = $CLASS_CACHE_OBJ;
  }

  return $obj;
}

sub exceeded_ops {
  my $self = shift;
  $self->has_exceeded_ops( 1 );
}

##
## removes the context and the runtime objects, so that we don't have
##   them hanging around.
##
sub cleanup_js_environment {
  my $self = shift;

  # The JS instance knows how to clean up after itself now using DEMOLISH
  #$self->context->cleanup;
}

##
## bootstraps the javascript environment
##
sub bootstrap {
  my $self = shift;

  # check to see if this host is active
  if(!$self->host->is_active){
    $self->config->info("Host '".$self->host->hostname."' is not currently active");
    die "Host '".$self->host->hostname."' is not currently active\n";
  }

  my $engine = $self->host->js_engine;
  my $je = $self->fetch_js_engine($engine);
    
  my $ji = $je->create_instance({ config => $self->host });

  $ji->runtime->set_opcount(0);
  $ji->runtime->set_opcount_limit( $self->host->oplimit );

  $ji->initialize;
  $self->context($ji);
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

    my $response;
    my $error;
    try {
        $response = $self->context->run([ $self->build_entrypoint_arguments ]);
        die $@ if $@;
        use Data::Dumper;
        local $Data::Dumper::Indent = 0;
        $self->config->info(Dumper($response));
    } catch {
        my $tmp = $_;
        if(blessed($tmp) eq 'JavaScript::Error') { 
            warn "howdy";
            $self->config->error("JS called failed with: " . $tmp->as_string);
            die $tmp;
         } else {
            my $str = $tmp;
            chomp($str);
            $self->config->error("JS called failed with: $str");
            die "$str\n";
        } 
    };

  if($self->has_exceeded_ops){
      $self->config->error("Request has exceeded oplimit");
      die "exceeded oplimit";
  }

  $self->ops($self->context->runtime->get_opcount);
  $self->encode_response( $response );
  $self->access_log();
}

sub access_log {
    my ($self, $log_message) = @_;
  
    # XXX disable access logging for now
    return;

    my $logfile = $self->host->access_log;
    open(my $fh, '>>', $logfile) or die "Could not open logfile '$logfile' for appending; $!";
    
    use Data::Dumper;
    print {$fh} sprintf(
        "[%s] (%s) %s - '%s %s HTTP/%s.%s'\n", 
        scalar(localtime),
        $self->hostname,
        $self->response->code,
        $self->request->method,
        $self->url,
        $self->request->major_version,
        $self->request->minor_version,
    );

    close $fh;
}

##
## terminates the transaction
##
sub end {
  my $self = shift;
  my $post_callback = shift;

  $self->report_consumption;
  if($self->{cache}){
      $self->{cache}->disconnect_all();
      undef( $self->{cache} );
  }
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
  if ( $self->config->does('RSP::Role::Config::AMQP') && (my $conf = $self->config->amqp) ) {
      Class::MOP::load_class('RSP::AMQP');
    my $amqp = RSP::AMQP->new(user => $conf->user, pass => $conf->pass);
    for my $report (@_){
        $amqp->send('rsp.consumption' => $report->as_json);
    }
  }

  foreach my $report (@_ ) {
    $self->config->info( "CONSUMPTION: " . $report->as_json );
  }
}

##
## instantiates or simply returns the RSP::Host object
##
sub host {
  my $self = shift;

  return $self->config->host($self->hostname);

=for comment
  ## allow for more "pluggable" host classes...
  my $host_class = $self->hostclass || $HOST_CLASS;
  if ( !$self->{host} ) {
    $self->{host} = $host_class->new( $self );
  }

  return $self->{host};
=cut

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
