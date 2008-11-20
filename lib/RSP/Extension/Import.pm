package RSP::Extension::Import;

use strict;
use warnings;

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'use' => sub {
       my $lib = shift;
       $lib =~ s/\./\//g;
       $lib .= ".js";
       $tx->context->eval_file( $tx->host->file( 'code', $lib ) );
       if ($@) {
        die $@;
       }
    }
  }
}

1;
