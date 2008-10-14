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

use Cache::Memcached::Fast;
use JSON::XS;
use Candomble::Broker;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'datastore' => {    
      'write'  => sub { 
        my ($type, $obj, $transient) = @_;
        if ( $transient ) {
          $class->write_cache( $tx, $type, $obj );
        } else { 
          Candomble::Broker->write($tx->host, @_)
        }
      },
      'remove' => sub { 
        my ($type, $id) = @_;
        $class->remove_cache( $tx, $type, $id );
        Candomble::Broker->delete($tx->host, @_ ) 
      },
      'search' => sub { Candomble::Broker->query($tx->host, @_ ) },
      'get'    => sub { 
        my ( $type, $id ) = @_;
        $class->read_cache( $tx, $type, $id ) || Candomble::Broker->read($tx->host, @_ ); 
      },
    }
  );
}

sub write_cache {
  my $class = shift;
  my $tx    = shift;
  my $type  = shift;
  my $obj   = shift;  
  $class->cache( $tx->host, $type )->set( $obj->{id}, $obj );
}

sub read_cache {
  my $class = shift;
  my $tx    = shift;
  my $type  = shift;
  my $id    = shift;
  $class->cache( $tx->host, $type )->get( $id );  
}

sub remove_cache {
  my $class = shift;
  my $tx    = shift;
  my $type  = shift;
  my $id    = shift;
  $class->cache( $tx->host, $type )->delete( $id );  
}

sub cache {
  my $class = shift;
  my $ns    = shift;
  my $type  = shift;
  my $cns   = join(':', __PACKAGE__, $ns, $type ) . ":";
  my $servers = [ map { { address => $_ } } grep { $_ } split(/,/, Candomble->config->{cache}->{hosts})];
  my $coder = JSON::XS->new->utf8;
  my $cache = Cache::Memcached::Fast->new({
    servers   => $servers,
    namespace => $cns,
    serialize_methods => [ sub { $coder->encode( $_[0] ) }, sub { $coder->decode( $_[0] ) } ],
    utf8 => 1,
  });
}

1;
