package RSP::Extension::PublicKey;

use strict;
use warnings;

use IO::File;

my $keyfile = '/home/git/.ssh/authorized_keys';

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'publickey' => {
      'remove' => sub {
        my $key = shift;
        my $kfh = IO::File->new("<$keyfile");
        if (!$kfh) { $tx->log("could not read keyfile: $!"); return 0; }
        my @keys;
        while(my $tkey = <$kfh>) {
          if ( $tkey ne $key ) {
            push @keys, $tkey;
          }
        }
        $kfh->close;
        my $wkfh = IO::File->new(">$keyfile");
        if (!$wkfh) { $tx->log("could not write keyfile: $!"); return 0; }
        $wkfh->print(join('',@keys));
        $wkfh->close();
        return 1;
      },
      'add' => sub {
        my $key = shift;
        my $kfh = IO::File->new(">>$keyfile");
        if (!$kfh) { $tx->log("could not append to keyfile: $!"); return 0; }
        $kfh->print( $key );
        $kfh->close();
      }
    }
  )
}

1;

