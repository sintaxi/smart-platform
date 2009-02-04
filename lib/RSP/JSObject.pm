package RSP::JSObject;

use strict;
use warnings;

sub bind {
  my $class = shift;
  my $tx    = shift;
  my $cx    = $tx->context;
  $cx->bind_class(
    name => $class->jsclass,
    package => $class,
    properties => $class->properties,
    methods => $class->methods,
  );
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
