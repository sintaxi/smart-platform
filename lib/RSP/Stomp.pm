package RSP::Stomp;

use strict;
use warnings;

my $CONN;

use RSP;
use Net::Stomp;

sub report {
  my $class = shift;
  my $conn  = $class->connection;
  foreach my $report (@_) {
    $conn->send({
		 destination    => 'rsp.consumption',
		 bytes_message  => 1,
		 body           => $report->as_json
		});
  }
}

sub connection {
  my $class = shift;
  if (!$CONN) {
    my $conf = RSP->config->{stomp};
    my $host = $conf->{host};
    my $port = $conf->{port};
    my $user = $conf->{user};
    my $pass = $conf->{pass};
    $CONN = Net::Stomp->new({hostname=> $host , port=> $port});
    $CONN->connect({login => $user, passcode => $pass});
  }
  return $CONN;
}

1;

