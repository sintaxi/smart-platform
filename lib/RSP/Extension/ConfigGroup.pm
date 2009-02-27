package RSP::Extension::ConfigGroup;

use strict;
use warnings;

use RSP::Error;
use base 'RSP::Extension';

use Module::Load qw();

sub group_classname {
  my $class = shift;
  return substr($class, rindex($class, "Extension::")+length("Extension::"));
}

sub groupname {
  return "storage";
}

sub providing_class_shortname {
  my $class = shift;
  my $group = RSP->config->{rsp}->{$class->groupname};
  my $name  = $class->group_classname;
  my $real  = RSP->config->{$group}->{$name};
  return $real;
}

sub providing_class {
  my $class = shift;
  my $name  = $class->group_classname;
  my $real  = $class->providing_class_shortname;
  my $full  = "RSP::Extension::" . $name . '::' . $real;
  eval { Module::Load::load( $full ) };
  if ($@) {
    RSP::Error->throw("couldn't load $name extension $full: $@");
  }
  if ( wantarray() ) {
    return ($full, $real);
  } else {
    return $full;
  }
}

1;
