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
        RSP->config->{server}->{Root},
        RSP->config->{hosts}->{Root},
        $tx->{host},
        RSP->config->{hosts}->{JSRoot},
        $lib
      );
      $tx->{context}->eval_file( $f );
      if ($@) {
        die $@;
      }
    }
  );
}

1;
