package Mock::Transaction;

use strict;
use warnings;

use JavaScript;

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  $self->{runtime} = JavaScript::Runtime->new;
  $self->{context} = $self->{runtime}->create_context;
  $self->{namespace} = shift;
  return $self;
}

sub hostname {
  my $self = shift;
  return $self->namespace(@_);
}

sub namespace {
  my $self = shift;
  return $self->{namespace};
}

sub context {
  my $self = shift;
  return $self->{context};
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
      'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{rsp}->{memcached}) } ],
      'namespace'         => $self->namespace . ':', ## append the colon for easy reading in mcinsight...
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
	'servers'           => [ { map { ('address' => $_) } split(',', RSP->config->{rsp}->{memcached}) } ],
      'namespace'         => $hostname . ':', ## append the colon for easy reading in mcinsight...
    });
  }
}

sub log {}

1;
