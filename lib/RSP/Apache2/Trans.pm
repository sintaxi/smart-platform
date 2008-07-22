package RSP::Apache2::Trans;

use strict;
use warnings;

use Apache2::Access ();
use Apache2::RequestUtil ();

use JSON::XS;
use HTTP::Request;
use RSP::Config;
use RSP::Transaction;
use RSP::ObjectStore;
use Apache2::Directive;
use Apache2::RequestRec;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);

sub handler {
  my $r = shift;    
  my $tree = Apache2::Directive::conftree();
  my $documentroot = $tree->lookup('VirtualDocumentRoot');
  warn("docroot is $documentroot");
  return Apache2::Const::DECLINED;
}

1;
