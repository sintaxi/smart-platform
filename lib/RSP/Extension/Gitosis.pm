package RSP::Extension::Gitosis;

use strict;
use warnings;

use File::Temp;
use base 'RSP::Extension';

use Git::Wrapper;

sub exception_name {
  return "gitosis";
}

sub provides {
  my $class = shift;
  my $tx   = shift;
  return {
	  gitosis => {
		      key => {
			      'write' => sub {
				my ($user, $key) = @_;
				$class->new( $tx )->write_key( $user, $key )
			      },
			      'exists' => sub {
				my $user = shift;
				if (!$user) { RSP::Error->throw('no user specified') }
				if ( $class->new( $tx )->check_key( $user ) ) {
				  return 1;
				} else {
				  return 0;
				}
			      }
			     },
		     }
  };
}

##
## this is a bit of a hack, but it lets me
##  create the git wrapper just once.
##
sub new {
  my $class = shift;
  my $tx    = shift;
  if ($tx->{ __gitosis__ }) {
    return $tx->{__gitosis__};
  }
  my $self = {};
  bless $self, $class;
  $tx->{__gitosis__} = $self;

  return $self;
}

sub gitosis {
  my $self = shift;
  $self->{wrapper} ||= Git::Wrapper->new( RSP->config->{gitosis}->{admin} );
}

sub write_key {
  my $self = shift;
  my $user = shift;
  my $key  = shift;

  my $gw    = $self->gitosis;
  my $gadir = $gw->dir;
  my $kf = File::Spec->catfile( $gadir, "keydir", sprintf("%s.pub", $user) );

  print "The keyfile is $kf\n";
  my $fh = IO::File->new( $kf, ">" );
  if (!$fh) {
    RSP::Error->throw("couldn't create key file");
  }
  $fh->print($key);
  $fh->close;

  eval {
    print "going to add the file...\n";
    $gw->add( File::Spec->catfile('keydir', sprintf("%s.pub", $user)) );
    $gw->commit( { all=>1, message=>"added key for user $user" } );
    $gw->push();
  };
  if ($@) {
    print "THERE WAS A PROBLEM....\n";
    RSP::Error->throw( $@ );
  }
}

sub check_key {
  my $self = shift;
  my $user = shift;

  my $gadir = $self->gitosis->dir;
  my $keyfile = File::Spec->catfile( $gadir, "keydir", sprintf("%s.pub", $user) );
  print "checking to see if the $keyfile exists...\n";
  -e $keyfile
}

1;
