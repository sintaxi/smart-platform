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
  my $self = shift;
  my $tx   = shift;
  return {
	  key => {
		  'write' => sub {
		    my ($user, $key) = @_;
		    $class->new( $tx )->write_key( $user, $key )
		  },
		  'check' => sub {
		    my $user = shift;
		    $class->new( $tx )->check_key( $user );
		  }
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
  if ( $self->{wrapper} ) {
    return $self->{wrapper};
  } else {
    my $conf = RSP->config->{gitosis};
    my $dir  = tempdir( CLEANUP => 1 );
    Git::Wrapper->new( $dir )->clone( $conf->{uri} );
    my $gadir = File::Spec->catfile( $dir, 'gitosis-admin' );
    my $gw = Git::Wrapper->new( $gadir );
    $self->{wrapper} = $gw;
    $self->{wrapper_dir} = $gadir;
    return $self->{wrapper};
  }
}

sub gitosis_dir {
  my $self = shift;
  return $self->{wrapper_dir};
}

sub write_key {
  my $self = shift;
  my $user = shift;
  my $key  = shift;

  my $gw    = $self->gitosis;
  my $gadir = $self->gitosis_dir;
  my $kf = File::Spec->catfile( $gadir, sprintf("%s.pub", $user) );
  my $fh = IO::File->new( $kf, ">" );
  if (!$fh) {
    RSP::Error->throw("couldn't create key file");
  }

  $fh->print($key);
  $fh->close;

  $gw->add( $kf );
  $gw->commit( { all=>1, message=>"added key for user $user" } );
}

sub check_key {
  my $self = shift;
  my $user = shift;

  my $gw    = $self->gitosis;
  my $gadir = $self->gitosis_dir;
  -e File::Spec->catfile( $gadir, sprintf("%s.pub", $user) );
}

1;
