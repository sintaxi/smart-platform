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
package RSP::Apache2::Trans;

use strict;
use warnings;

use Apache2::Access ();
use Apache2::RequestUtil ();

use JSON::XS;
use HTTP::Request;
use RSP::Config;
use RSP::Transaction;
use RSP::ObjectStore;
use Apache2::Directive;
use Apache2::RequestRec;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);

sub handler {
  my $r = shift;    
  my $tree = Apache2::Directive::conftree();
  my $documentroot = $tree->lookup('VirtualDocumentRoot');
  warn("docroot is $documentroot");
  return Apache2::Const::DECLINED;
}

1;
