package RSP;

use strict;
use warnings;

use Config::Tiny;
use File::Spec;

our $AUTOLOAD;
our @CONFIGDIR = ( './etc','/etc' );
our $MTIME = 0;
our $CONFIG;
our $CONFIG_FILENAME;

sub RSP::config {
  my $class = shift;

  ## get the config file once, then we're done...
  $CONFIG_FILENAME ||= $class->find_config_file;

  ## get the mtime, if it's greater than what we
  ## have we need to re-read the config file, otherwise
  ## simply return what we have cached.
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
    $atime,$mtime,$ctime,$blksize,$blocks)
        = stat($CONFIG_FILENAME);
  if ( $mtime > $MTIME ) {
    $CONFIG = Config::Tiny->read( $CONFIG_FILENAME );
    $MTIME  = $mtime;
    return $CONFIG;
  } else {
    return $CONFIG;
  }
}

sub find_config_file {
  foreach my $dir ( @CONFIGDIR ) {
    my $cf = File::Spec->catfile( $dir, 'rsp.conf' );  
    if (-e $cf && -f $cf ) {
      return $cf;
    }
  }
}



1;
