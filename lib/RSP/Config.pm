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
  $CONFIG_FILENAME ||= $class->find_config_file;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
    $atime,$mtime,$ctime,$blksize,$blocks)
        = stat($CONFIG_FILENAME);
  if ( $mtime > $MTIME ) {
    print STDERR "reading config file\n";
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
