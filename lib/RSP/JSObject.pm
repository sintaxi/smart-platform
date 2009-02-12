package RSP::JSObject;

use strict;
use warnings;

use base 'Class::Accessor::Chained';

our @BOUND_CLASSES = ();

sub bind {
  my $class = shift;
  my $tx    = shift;
  my $cx    = $tx->context;
  my $opts  = {
	       name       => $class->jsclass,
	       package    => $class,
	       properties => $class->properties,
	       methods    => $class->methods,
	      };
  if ( $class->can('constructor') ) {
    $opts->{constructor} = $class->can('constructor')->();
  }
  $cx->bind_class( %$opts );
  push @BOUND_CLASSES, $class->jsclass;
}

sub unbind {
  my $class = shift;
  my $cx    = shift;
  $cx->unbind_value( $_ ) foreach @BOUND_CLASSES;
}

sub jsclass {
  return undef;
}

sub methods {
  return {};
}

sub properties {
  return {};
}

1;
