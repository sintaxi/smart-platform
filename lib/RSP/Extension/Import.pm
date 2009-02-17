package RSP::Extension::Import;

use strict;
use warnings;

use RSP::Error;
use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'use' => sub {
       my $lib = shift;
       my $orig = $lib;

       $lib =~ s/\./\//g;
       $lib .= ".js";
       if (!-e $lib) {
	 RSP::Error->throw("library $orig does not exist");
       }
       $tx->context->eval_file( $tx->host->file( 'code', $lib ) );
       if ($@) {
	 RSP::Error->throw($@);
       }
    }
  }
}

1;
