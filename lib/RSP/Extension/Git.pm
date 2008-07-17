package RSP::Extension::Git;

use strict;
use warnings;

use Git;
use JavaScript;
use Git::Wrapper;

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

        my $rt   = JavaScript::Runtime->new;
        my $cx   = $rt->create_context;     
        
        eval {
          ## this is stuff to make the database...
          my $ntx  = RSP::Transaction->start(
            $cx,
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
        my $gw = Git::Wrapper->new( File::Spec->catfile( $tx->gitroot, $host ) );
        $gw->reset('--hard', 'HEAD') or return 0;
        return 1;
      },
      'current_branch' => sub {
        my $host = shift;
        my $gw   = Git::Wrapper->new( File::Spec->catfile( $tx->gitroot, $host ) );
        return [ $gw->branch ];
      }
    }
  
  
  );
}

1;
