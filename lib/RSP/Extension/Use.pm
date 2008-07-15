package RSP::Extension::Use;

use strict;
use warnings;

use File::Spec;

sub provide {
  my $class = shift;
  my $tx    = shift;
  return ( 
    'use' => sub {
      my $lib = shift;
      $lib =~ s!\.!/!g;
      $lib .= '.js';
      my $f = File::Spec->catfile(
        $tx->jsroot,
        $lib
      );
      $tx->{context}->eval_file( $f );
      if ($@) {
        die $@;
      } else {
      }
    }
  );
}

1;
