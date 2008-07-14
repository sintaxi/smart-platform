package RSP;

use strict;
use warnings;

use Config::Tiny;
use File::Spec;

our $AUTOLOAD;
our @CONFIGDIR = ( './etc','/etc' );

sub RSP::config {
  my $class = shift;  
  foreach my $dir ( @CONFIGDIR ) {
    my $cf = File::Spec->catfile( $dir, 'rsp.conf' );
    if (-e $cf && -f $cf ) {
      my $config = Config::Tiny->read( $cf );
      return $config;
    }
  }
}



1;
