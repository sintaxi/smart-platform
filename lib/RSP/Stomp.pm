package RSP::Stomp;

use strict;
use warnings;

use RSP;
use Net::Stomp;

sub report {
  my $class = shift;
  my $conn  = $class->connection;
  foreach my $report (@_) {
    $class->send( 'rsp.consumption', $report->as_json );
  }
}

sub send {
  my $class = shift;
  my $dest  = shift;
  my $mesg  = shift;
  my $conn  = $class->connection;
  $conn->send({
	       destination   => $dest,
	       bytes_message => 1,
	       body          => $mesg
	      });
}

sub connection {
  my $class = shift;
  my $conf = RSP->config->{stomp};
  my $host = $conf->{host};
  my $port = $conf->{port};
  my $user = $conf->{user};
  my $pass = $conf->{pass};
  my $CONN = Net::Stomp->new({hostname=> $host , port=> $port});
  $CONN->connect({login => $user, passcode => $pass});
  return $CONN;
}

1;

