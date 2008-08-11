package RSP::Server::Single;

##
## useful for debugging....
##
##

use strict;
use warnings;

use RSP;

use POSIX;
use IO::File;
use HTTP::Status;
use HTTP::Daemon;



{
  no warnings 'redefine';
  sub HTTP::Daemon::product_tokens {
    return join("/", __PACKAGE__, $RSP::VERSION, "debugging");
  }
}

sub start {
  $0 = HTTP::Daemon->product_tokens();
  run();
}

sub run {
  my $master = HTTP::Daemon->new( %{ RSP->config->{daemon} } )
    or die "Cannot create master: $!";

  my $PIDFILE = File::Spec->catfile( RSP->config->{server}->{Root}, 'run', 'rsp.pid' );

  my $fh = IO::File->new($PIDFILE, ">");
  if (!$fh) {
    die "could not open $PIDFILE: $!";
  } else {
    $fh->print($$);
    $fh->close;
  }

  while( my $client = $master->accept ) {
    handle_one_connection( $client );
  }
  
}

sub handle_one_connection {
  my $c = shift;
  my $this_conn = 0;
  eval {
    my $notimeout;
    local $SIG{ALRM} = sub {
      if ($notimeout) { die "alarm"; }
    };
    $notimeout = 1;
    alarm(RSP->config->{server}->{ConnectionTimeout} || 60);
    while( my $r = $c->get_request ) {    
      alarm(60);
      $notimeout = 0;
      $this_conn++;    
      my $response = eval { RSP->handle( $r ) };
      if ($@) {
        $c->send_error(RC_INTERNAL_SERVER_ERROR, $@);
      } else {
        $c->send_response( $response );      

        if ($response->header('Connection') && $response->header('Connection') =~ /close/i) {
          last;
        }
      }
      if ( $this_conn == ( RSP->config->{server}->{MaxRequetsPerClient} || 5 )) {
        last;
      }
    }  
  };
  alarm(0);
  $c->close;
}


1;
