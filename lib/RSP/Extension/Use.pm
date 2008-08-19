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
package RSP::Extension::Use;

use strict;
use warnings;

use File::Spec;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return ( 
    'use' => sub {
      my $lib = shift;
      $lib =~ s!\.!/!g;
      $lib .= '.js';
      my $f = File::Spec->catfile(
        $tx->jsroot,
        $lib
      );
      $tx->{context}->eval_file( $f );
      if ($@) {
        $tx->log("failed to load $f: " . $@);
        die $@;
      } else {
      }
    }
  );
}

1;
