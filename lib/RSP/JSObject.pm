package RSP::JSObject;

use strict;
use warnings;

use base 'Class::Accessor::Chained';

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
