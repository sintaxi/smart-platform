package RSP::Extension::FileSystem;

use strict;
use warnings;

use base 'RSP::Extension';
use RSP::JSObject::File;

sub provides {
  my $class = shift;
  my $tx    = shift;

  RSP::JSObject::File->bind( $tx->context );
  
  return {
    'filesystem' => {
      'get' => sub {
        my $rsp_path  = shift;
        my $real_path = $tx->host->file( 'web', $rsp_path );
        return RSP::JSObject::File->new( $real_path, $rsp_path );
      }
    }
  };
}


1;
