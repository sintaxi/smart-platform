package RSP::Extension::FileSystem;

use strict;
use warnings;

use base 'RSP::Extension';
use RSP::JSObject::File;

sub extension_name {
  return "system.filesystem";
}

sub provides {
  my $class = shift;
  my $tx    = shift;

  RSP::JSObject::File->bind( $tx );

  return {
    'filesystem' => {
      'get' => sub {
        my $rsp_path  = shift;
        my $real_path = $tx->host->file( 'web', $rsp_path );
	if ( -f $real_path ) {
	  return RSP::JSObject::File->new( $real_path, $rsp_path );
	} else {
	  RSP::Error->throw($!);
	}
      }
    }
  };
}


1;
