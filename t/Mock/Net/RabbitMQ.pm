package Net::RabbitMQ;
use unmocked 'Moose';

our $CURRENT_CHANNEL;
sub channel_open {
    my ($self, $chan) = @_;
    $CURRENT_CHANNEL = $chan;
}

our $CONNECT_DETAILS;
our $DISCONNECTED;
sub connect {
    my ($self, $host, $opts) = @_;
    $DISCONNECTED = 0;
    $CONNECT_DETAILS = { host => $host, %$opts };
}

sub disconnect {
    $DISCONNECTED = 1;
}

our $PUBLISHED;
sub publish {
    my ($self, $chan, $route_key, $msg, $opts) = @_;
    $PUBLISHED = { channel => $chan, route_key => $route_key, msg => $msg, %$opts };
}

our $LAST_CHANNEL_CLOSED;
sub channel_close {
   my ($self, $chan) = @_;
   $LAST_CHANNEL_CLOSED = $chan;
}


1;
