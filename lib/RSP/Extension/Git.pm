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
