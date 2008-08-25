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
package RSP::Extension::Template;

use strict;
use warnings;

use Template;
use Scalar::Util qw( blessed );

use Template::Plugins;

$Template::Plugins::STD_PLUGINS = {};
$Template::Plugins::PLUGIN_BASE = '';

sub provide {
  my $class = shift;
  my $tx    = shift;
  return (
    'template' => sub {
      $tx->profile('template');
      my $template = shift;
      my $templateData = shift;
      
      my $procstring;
      if ( blessed( $template ) ) {
        $procstring = $template->fullpath;
      } else {
        $procstring = \$template;
      }
      my $tt = Template->new( 
        PLUGINS => {},
        INCLUDE_PATH => [ $tx->webroot ],
        ABSOLUTE     => 1,
        RECURSION => 1
      );
      my $buf;
      
      $tt->process($procstring, $templateData, \$buf) or warn $tt->error;
      $tx->profile('template');
      return $buf;    
    }
  );
}

1;
