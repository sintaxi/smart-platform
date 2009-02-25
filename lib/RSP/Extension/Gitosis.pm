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
				return $class->new( $tx )->check_key( $user );
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
  my $self = {};
  bless $self, $class;
  return $self;
}

sub write_key {
  my $self = shift;
  my $user = shift;
  my $key  = shift;
  my $file = File::Spec->catfile(
				 RSP->config->{keymanager}->{keydir},
				 sprintf("%s.pub", $user)
				);
  my $fh = IO::File->new( $file, ">" );
  if (!$fh) {
    RSP::Error->throw("could not open keyfile for writing");
  }
  $fh->print( $key );
  $fh->close();
}

sub check_key {
  my $self = shift;
  my $user = shift;

  my $keyfile = File::Spec->catfile(
				    RSP->config->{gitosis}->{admin},
				    'keydir',
				    sprintf('%s.pub', $user)
				   );
  -e $keyfile
}

1;
