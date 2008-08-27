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
package RSP::Extension::Git;

use strict;
use warnings;

use Git;
use JavaScript;
use File::Find::Rule;
use Git::Wrapper;
use Cache::Memcached::Fast;

my $coder = JSON::XS->new->ascii->allow_nonref;
my $mdservers = [ {address => '127.0.0.1:11211'} ];


=head1 Name

Git - bindings to the version control layer of the RSP.

=head1 Structure

=over 4

=item git

=over 4

=item Boolean update( String hostname );

Gets the latest version of the code from the git repository for hostname.

=item Boolean clone( String origin, String hostname )

Clone an existing git repository at origin for the host hostname.  This also
sends in a fake request so that the database gets set up early.


=item String current_branch( String hostname )

Gets the name of the current branch of the git repository containing the code
for hostname.

=item String remove( String hostname )

Removes the git repository, and all the data for a host.


=back

=back

=cut

sub provide {
  my $class = shift;
  my $tx    = shift;
  
  return (
  
    'git' => {
      'clone' => sub {
        my $origin = shift;
        my $host   = shift;
        {
          Git::Wrapper->new( $tx->gitroot )->clone( $origin, $host ) or return 0;
        }
        my $gw = Git::Wrapper->new( File::Spec->catfile( $tx->gitroot, $host ) );
        $gw->update_server_info();
        
        eval {
          ## this is stuff to make the database...
          my $ntx  = RSP::Transaction->start(
            HTTP::Request->new('GET','/', ['Host', $host])
          );
          mkdir( $ntx->dbroot );        
        };
        if ($@) {
          $tx->log( $@ );
          return 0;
        }
        
        return 1;
      },
      'update' => sub {
        my $host = shift;
        eval {
          my $mcdkey = "$tx->{host}:$host:branches";
          my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
          $md->delete( $mcdkey );
          my $gw = Git::Wrapper->new( File::Spec->catfile( $tx->gitroot, $host ) );
          if (!$gw->reset('--hard', 'HEAD')) {
            $tx->log("couldn't update");
            return 0;
          }
          $gw->update_server_info();
        };
        if ($@) {
          $tx->log("could not update: " . $@);
        }
        return 1;
      },
      'current_branch' => sub {
        my $host = shift;
        my $mcdkey = "$tx->{host}:$host:branches";
        my $md = Cache::Memcached::Fast->new( { servers => $mdservers } );
        my $branches = $md->get($mcdkey);
        if ( $branches ) { warn("got branches from cache with key $mcdkey"); return $coder->decode( $branches ); }
        my $gw   = Git::Wrapper->new( File::Spec->catfile( $tx->gitroot, $host ) );
        my $branch = [ $gw->branch ];
        $md->set( $mcdkey, $coder->encode( $branch ) );
        return $branch;
      },
      'remove' => sub {
        my $host = shift;
        my @files = File::Find::Rule->file()
                                    ->name( '*', '.*' )
                                    ->in( File::Spec->catfile( $tx->gitroot, $host ) );
        foreach my $file (@files) {
          unlink( $file );
        }
        
        my @dirs = reverse sort { 
          length($a) <=> length($b)
        } File::Find::Rule->directory()
                                    ->name( '*', '.*' )
                                    ->in( File::Spec->catfile( $tx->gitroot, $host ) );        
        foreach my $dir (@dirs) {
          print "rmdir $dir\n";
          rmdir( $dir );
        }
        rmdir( File::Spec->catfile( $tx->gitroot, $host ) );
        unlink( File::Spec->catfile( RSP->config->{db}->{Root}, RSP->config->{db}->{File} ) );
        rmdir( File::Spec->catfile( RSP->config->{db}->{Root}, $host ) );
        return 1;
      }
    }
  
  
  );
}

1;
