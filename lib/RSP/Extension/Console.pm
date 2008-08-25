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
package RSP::Extension::Console;

use strict;
use warnings;

=head1 Name

Console - log information to the console

=head1 Structure

=over 4

=item console

=over 4

=item log( aMessage )

Logs aMessage to the console

=back

=back

=cut

sub provide {
  my $class = shift;
  my $tx    = shift;
  return ( console => {
    log => sub {
      my $mesg = shift;
      $tx->log( $mesg );
    }
  });
}

1;
