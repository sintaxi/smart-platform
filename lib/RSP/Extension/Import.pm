package RSP::Extension::Import;

use strict;
use warnings;

use RSP::Error;
use base 'RSP::Extension';

sub extension_name {
  return "system.use";
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'use' => sub {
       my $lib = shift;
       my $orig = $lib;

       $lib =~ s/\./\//g;
       $lib .= ".js";
       my $path = $tx->host->file('code', $lib);
       if (!-e $path) {
	 RSP::Error->throw("library $orig does not exist");
       }
       $tx->context->eval_file( $path );
       if ($@) {
	 RSP::Error->throw($@);
       }
    }
  }
}

1;
