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
package RSP::Extension::SetupHost;

use strict;
use warnings;
use JavaScript;
use HTTP::Request;
use Git::Wrapper;

sub provide {
  return (
    'host' => {
      'create' => sub {
        my $host = shift;
        my $rt   = JavaScript::Runtime->new;
        my $cx   = $rt->create_context;        
        my $ntx  = RSP::Transaction->start(
          $cx, 
          HTTP::Request->new('GET','/', ['Host', $host])
        );
        mkdir( $ntx->dbroot );
        my $hostsroot = File::Spec->catfile(
          RSP->config->{server}->{Root},
          RSP->config->{hosts}->{Root}
        );
        eval {
          my $git = Git::Wrapper->new( $hostsroot );
          $ntx->log("git root is " . $ntx->gitroot);
          $git->clone( $ntx->gitroot, $ntx->{host} );
        };
        if ($@) {
          $ntx->log("setup phase one: clone failed: " . $@);
          return undef;
        } else {
          eval {
            my $git = Git::Wrapper->new( $ntx->hostroot );
            $git->branch( $ntx->{host} );
            $git->checkout( $ntx->{host} );
          };
          if ($@) {
            $ntx->log("couldn't branch to $ntx->{host}");
            die { error => $@ };
          }
        }
        return 1;
      },
      'teardown' => sub {
      
      }
    }
  );
}

1;
