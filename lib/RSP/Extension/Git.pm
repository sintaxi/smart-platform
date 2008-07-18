package RSP::Extension::Git;

use strict;
use warnings;

use Git;
use JavaScript;
use File::Find::Rule;
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
      },

      'remove' => sub {
        my $host = shift;
        my @files = File::Find::Rule->file()
                                    ->name( '*' )
                                    ->in( File::Spec->catfile( $tx->gitroot, $host ) );
        foreach my $file (@files) {
          unlink( $file );
        }
        
        my @dirs = sort { 
          length($a) <=> length($b)
        } File::Find::Rule->directory()
                                    ->name( '*' )
                                    ->in( File::Spec->catfile( $tx->gitroot, $host ) );        
        foreach my $dir (@dirs) {
          print "rmdir $dir\n";
          rmdir( $dir );
        }
        rmdir( File::Spec->catfile( $tx->gitroot, $host ) );
        unlink( File::Spec->catfile( RSP->config->{db}->{Root}, RSP->config->{db}->{File} ) );
        rmdir( RSP->config->{db}->{Root} );
        return 1;
      }
    }
  
  
  );
}

1;
