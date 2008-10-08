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

package RSP::Extension::Candomble;

use strict;
use warnings;

use Candomble::Broker;
use Data::Dumper;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'datastore' => {    
      'write'  => sub { print Dumper(["write",$tx->host,@_]); Candomble::Broker->write($tx->host, @_)},
      'remove' => sub { print Dumper(["delete",$tx->host,@_]); Candomble::Broker->delete($tx->host, @_ ) },
      'search' => sub { print Dumper(["query",$tx->host,@_]); Candomble::Broker->query($tx->host, @_ ) },
      'get'    => sub { print Dumper(["read",$tx->host,@_]); Candomble::Broker->read($tx->host, @_ ); },

    }
  );
}

1;
