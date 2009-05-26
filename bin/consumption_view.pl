#!/usr/bin/env perl

use strict;
use warnings;

use RSP::Stomp;

my $stomp = RSP::Stomp->connection;
$stomp->subscribe({'destination'=>'rsp.consumption', 'ack'=>'client'});

while (1) {
    my $frame = $stomp->receive_frame;
    print $frame->body . "\n";
    $stomp->ack({frame=>$frame});
    last if $frame->body eq 'QUIT';
}
$stomp->disconnect;
