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
          $git->clone( $ntx->gitroot, $ntx->{host} );
        };
        if ($@) {
          $ntx->log($@);
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
