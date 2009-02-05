package RSP::Extension::ConfigGroup;

use strict;
use warnings;

use base 'RSP::Extension';

use Module::Load qw();

sub providing_class {
  my $class = shift;
  my $group = RSP->config->{rsp}->{storage};
  my $name  = substr($class, rindex($class, "Extension::")+length("Extension::"));
  my $real  = RSP->config->{$group}->{$name};
  my $full  = "RSP::Extension::" . $name . '::' . $real;
  eval { Module::Load::load( $full ) };
  if ($@) {
    die "couldn't load $name extension $full: $@";
  }
  return $full;
}

1;
