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

package RSP::Extension::Datastore;

use strict;
use warnings;

use RSP::ObjectStore;

=head1 Name

Datastore - create, update, delete and query objects to the datastore.

=head1 Structure

=over 4

=item datastore

=over 4

=item Boolean write(String aType, Object anObject[, Boolean isTransient])

Writes anObject of type aType to the datastore.  If the isTransient parameter
is set to true then the object is written I<only> to the memory store, and
may be deleted at any time.

anObject I<must> have an id attribute to be stored.

=item Object get(String aType, String anId)

Gets an object of type aType having the id anId from the datastore.

=item Boolean remove(String aType, String anId)

Removes an object from the datastore.

=item Array search(String aType, Object aQuery)

The search method queries the object store for objects of aType matching 
the query aQuery.

=back

=back

=cut

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'datastore' => {
    
      'write'  => sub { my $os = RSP::ObjectStore->new( $tx ); $os->write(@_) },
      'remove' => sub { my $os = RSP::ObjectStore->new( $tx ); $os->remove( @_ ) },
      'search' => sub { my $os = RSP::ObjectStore->new( $tx ); $os->search( @_ ) },
      'get'    => sub { my $os = RSP::ObjectStore->new( $tx ); $os->get( @_ ); },

    }
  );
}

1;
