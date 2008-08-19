#    This file is part of the RSP.
#
#    The RSP is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    The RSP is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with the RSP.  If not, see <http://www.gnu.org/licenses/>.

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
