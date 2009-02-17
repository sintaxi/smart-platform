package RSP::Error;

use strict;
use warnings;

sub throw {
  my $class = shift;
  my $mesg  = shift;

  chomp $mesg;

  my $pack  = caller();
  if ( $pack->can("extension_name") ) {
    $pack = $pack->can('extension_name')->();
  }

  if ( $mesg =~ /\s+at ((.+)\.pm) line/) {
    $mesg =~ s/\s+at ((.+)\.pm) line .+$//;
  }
  die { message => $mesg, fileName => $pack };
}

1;

