package RSP::Extension::Image;

use strict;
use warnings;

use RSP::JSObject::Image;
use base 'RSP::Extension';

sub bind_class {
  return 'RSP::JSObject::Image';
}

sub provides {
  my $self = shift;
  $self->SUPER::provides(@_);

  my $tx = shift;
  $self->bind_class->bind( $tx );
}

1;

