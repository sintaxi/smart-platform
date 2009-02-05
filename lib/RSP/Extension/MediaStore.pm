package RSP::Extension::MediaStore;

use strict;
use warnings;

use base 'RSP::Extension::ConfigGroup';

sub provides {
  my $class = shift;
  my $tx    = shift;

  ##
  ## bind the mediafile type to the context.
  ##
  $class->bind_class->bind( $tx );


  return {
	  mediastore => {
			 write  => sub { $class->write( $tx, @_ ) },
			 remove => sub { $class->remove( $tx, @_ ) },
			 get    => sub { $class->get( $tx, @_ ) },
			}
	 };
}

1;


