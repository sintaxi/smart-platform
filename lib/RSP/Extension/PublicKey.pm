#    This file is part of the RSP.
#
#    The RSP is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    The RSP is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with the RSP.  If not, see <http://www.gnu.org/licenses/>.
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
          if ( $tkey =~ $key ) {
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

