package LWP::UserAgent;

use unmocked 'Moose';
use unmocked 'HTTP::Response';
use unmocked 'HTTP::Request';

our $AGENT_STRING;
sub agent {
    my ($self, $string) = @_;
    $AGENT_STRING = $string;
}

our $TIMEOUT;
sub timeout {
    my ($self, $timeout) = @_;
    $TIMEOUT = $timeout;
}

our $RESPONSE;
our $REQUEST;
sub request {
    my ($self, $req) = @_;
    $REQUEST = $req;
    my $res = HTTP::Response->new(@$RESPONSE);
    return $res;
}

1;
