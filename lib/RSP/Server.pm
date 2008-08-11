## Ideas from:
## http://www.stonehenge.com/merlyn/WebTechniques/col34.listing.txt

package RSP::Server;

use RSP;

use POSIX;
use IO::File;
use HTTP::Status;
use HTTP::Daemon;

our $VERSION = '3.00';

{
  no warnings 'redefine';
  sub HTTP::Daemon::product_tokens {
    return join("/", __PACKAGE__, $RSP::VERSION);
  }
}

sub start {
  $0 = HTTP::Daemon->product_tokens();
  setup_signals();
  run();
}

sub stop {
  my $CONFIG  = RSP->config();
  my $PIDFILE = File::Spec->catfile( $CONFIG->{server}->{Root}, 'run', 'rsp.pid' );
  my $fh = IO::File->new( $PIDFILE );
  my $pid = $fh->getline;
  $fh->close;
  if ( kill 15, $pid ) {
    unlink $PIDFILE;
  } else {
    warn "Couldn't kill proces $pid\n";
  }
}

sub handle_one_connection {
  my $c = shift;
  #my $r = $c->get_request;
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

sub run {
  my %kids;

  my %opts = (
    Reuse => 1,
    ReuseAddr => 1
  );
  
  my $CONFIG  = RSP->config();
  my $PIDFILE = File::Spec->catfile( $CONFIG->{server}->{Root}, 'run', 'rsp.pid' );

  if ( fork() ) {
    exit;
  }
  
  my $master = HTTP::Daemon->new( %{ $CONFIG->{daemon} } )
    or die "Cannot create master: $!";

  my $fh = IO::File->new($PIDFILE, ">");
  if (!$fh) {
    die "could not open $PIDFILE: $!";
  } else {
    $fh->print($$);
    $fh->close;
  }

  if ( $CONFIG->{server}->{User} ) {
   {
      my ($name,$passwd,$gid,$members) = getgrnam( $CONFIG->{server}->{Group} );
      if ($gid) {
        POSIX::setgid( $gid );
        if ($!) { warn "setgid: $!" }
      } else {
        die "unknown user $CONFIG->{server}->{User}";
      }
   }
    {
      my ($name,$passwd,$uid,$gid, $quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam( $CONFIG->{server}->{User} );
      if ($uid) {
        POSIX::setuid( $uid );
	if ($!) { warn "setuid: $!" }
      } else {
        die "unknown user $CONFIG->{server}->{User}";
      }
   }

  }


  for (1..$CONFIG->{server}->{MaxClients}) {
    $kids{&fork_a_slave($master)} = "slave";
  }
  {                             # forever:
    my $pid = wait;
    my $was = delete ($kids{$pid}) || "?unknown?";
    if ($was eq "slave") {      # oops, lost a slave
      sleep 1;                  # don't replace it right away (avoid thrash)
      $kids{&fork_a_slave($master)} = "slave";
    }
  } continue { redo };          # semicolon for cperl-mode
  

}

sub setup_signals {             # return void
  setpgrp;                      # I *am* the leader
  $SIG{HUP} = $SIG{INT} = $SIG{TERM} = sub {
    my $sig = shift;
    $SIG{$sig} = 'IGNORE';
    kill $sig, 0;               # death to all-comers
    exit;
  };
}

sub fork_a_slave {              # return int (pid)
  my $master = shift;           # HTTP::Daemon

  my $pid;
  defined ($pid = fork) or die "Cannot fork: $!";
  &child_does($master) unless $pid;
  $pid;
}

sub child_does {                # return void
  my $master = shift;           # HTTP::Daemon

  my $did = 0;                  # processed count

  my $config = RSP->config;
  {
    flock($master, 2);          # LOCK_EX
    my $slave = $master->accept or die "accept: $!";
    flock($master, 8);          # LOCK_UN
    my @start_times = (times, time);
    $slave->autoflush(1);
    handle_one_connection($slave); # closes $slave at right time
  } continue { redo if ++$did < $config->{server}->{MaxRequestsPerChild} };
  exit 0;
}


1;
