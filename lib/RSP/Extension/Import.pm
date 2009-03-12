package RSP::Extension::Import;

use strict;
use warnings;

use RSP::Error;
use base 'RSP::Extension';

sub exception_name {
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
       my $path = $class->path_to_lib( $tx, $lib );
       if (!$path) {
	 RSP::Error->throw("library $orig does not exist");
       }
       $tx->context->eval_file( $path );
       if ($@) {
	 $tx->log($@);
	 RSP::Error->throw($@);
       }
    }
  }
}

sub path_to_lib {
  my $class = shift;
  my $tx    = shift;
  my $lib   = shift;
  return $class->local_lib( $tx, $lib ) || $class->global_lib( $tx, $lib );
}

sub global_lib {
  my $class = shift;
  my $tx    = shift;
  my $lib   = shift;
  my $path = File::Spec->catfile( RSP->config->{_}->{root}, 'library', $lib );
  if ( -e $path ) {
    return $path;
  }
  return undef;
}

sub local_lib {
  my $class = shift;
  my $tx    = shift;
  my $lib   = shift;
  my $path  = $tx->host->file( 'code', $lib );
  if ( -e $path ) {
    return $path;
  }
  return undef;
}



1;
