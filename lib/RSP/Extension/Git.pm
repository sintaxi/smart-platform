package RSP::Extension::Git;

use strict;
use warnings;

use Git;
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
