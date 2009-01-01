package RSP::Transaction;

use strict;
use warnings;

use JavaScript;
use Module::Load qw();
use Cache::Memcached::Fast;
use Hash::Merge::Simple 'merge';
use base 'Class::Accessor::Chained';

our $HOST_CLASS = RSP->config->{_}->{host_class} || 'RSP::Host';

__PACKAGE__->mk_accessors(qw( request response runtime context ));

sub import {
  Module::Load::load( $HOST_CLASS );
}

##
## simple constructor, returns a new RSP::Transaction
##
sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
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
    print "could not bootstrap $bs_file\n";
    die $!;
  }
  $self->context->eval_file( $bs_file );
  if ($@) {
    print "could not bootstrap $bs_file\n";
    die $@;
  }
}

##
## this handles all the javascripty stuff
##
sub run {
  my $self = shift;
  my $response = $self->context->call('main');
  if ($@) {
    if (ref($@) && ref($@) eq "JavaScript::Error") {
      die "$@->{message} at $@->{fileName} line $@->{lineNumber}";
    } else {
      die $@;
    }
  } else {
    my @resp = @$response;

    my ($code, $codestr, $headers, $body) = @resp;
    $self->response->code( $code );
    my @headers = @$headers;
    while( my $key = shift @headers ) {
      my $value = shift @headers;
      ## why do we need to special case this?
      if ( $key eq 'Set-Cookie') {
        my $cookies = Mojo::Cookie::Response->new->parse( $value );
        $self->response->cookies( $cookies->[0] );
      } else {
        $self->response->headers->add_line( $key, $value );
      }
    }
    
    ##
    ## if we have a simple body string, use that, otherwise
    ##  we need to be a bit more clever
    ##
    if (!ref($body)) {
      $self->response->body( $body );
    } else {
      if ( ref($body) eq 'JavaScript::Function' ) {
        ## it's a javascript function, call it and use the
        ## returned data
        $self->response->body( $body->() );
      } elsif ( ref($body) && $body->isa('RSP::JSObject') ) {
        ##
        ## it's a blended object, most likely ( at this point ) a file.
        ##   suck the data up and use that
        ##
        $self->response->body( $body->as_string );
      } else {
        ##
        ## we don't know what to do with it.
        ##
        die "don't know what to do with " . ref($body) . " object";
      }
    }
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
    Module::Load::load( $ext );
    if (!$@) {
      my $provided = $ext->provides( $self );
      if ( !$provided ) {
        warn "no extensions provided by $ext";
      } elsif (!ref($provided) || ref($provided) ne 'HASH') {
        warn "invalid extension provided by $ext";
      } else {
        $sys = merge $provided, $sys;
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
  
  if ( !$self->{host} ) {
    $self->{host} = $HOST_CLASS->new( $self ); 
  }
  
  return $self->{host};
}


sub log {
  my $self = shift;
  my $mesg = shift;
  print STDERR sprintf("[%s] %s\n", $self->host->hostname, $mesg);
}

1;
