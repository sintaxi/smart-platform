#!/usr/bin/perl

use strict;
use warnings;

use IO::Socket::INET;
use Net::Rendezvous::Publish;

my $publisher = Net::Rendezvous::Publish->new;
my $service   = $publisher->publish( name => 'CouchDB', type => '_http._tcp', port => 5984, domain => 'local' );
while( test_socket() ) {
  $publisher->step( 0.01 );
}

sub test_socket {
  my $sock = IO::Socket::INET->new( PeerAddr => "localhost", PeerPort => 5984 );
  if ( $sock->connected ) {
    $sock->close;
    return 1;
  } else {
    return 0;
  }
}