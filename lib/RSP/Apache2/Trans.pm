package RSP::Apache2::Trans;

use strict;
use warnings;

use Apache2::RequestRec;

use Apache2::Const -compile => qw( DECLINED );

sub handler {
  my $r = shift;
  my $hostname = $r->headers_in->{Host};
  $hostname =~ s!\:\d+$!!;

  $r->uri("/$hostname" . $r->uri);

  return Apache2::Const::DECLINED;
}

1;
