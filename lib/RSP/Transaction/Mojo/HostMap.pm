package RSP::Transaction::Mojo::HostMap;

use strict;
use warnings;

sub firstdir {
  my $class = shift;
  my $req   = shift;
  my $parts = $req->url->path->parts;
  my $host = shift @$parts;
  
  $req->url->path->parts( @$parts );
  
  return $host;
}

sub hostname {
  my $class = shift;
  my $req  = shift;
  my $host;
  if ( ref( $req->headers->host ) ) {
    $host = $req->headers->host->[0];
  } else {
    $host = $req->headers->host;
  }
  return $class->strip_hostname( $host );
}

##
## strips the port number of a hostname, if there is one
##
sub strip_hostname {
  my $self = shift;
  my $host = shift || die "no hostname";
  $host =~ s/:.+$//;
  return $host;
}


1;
