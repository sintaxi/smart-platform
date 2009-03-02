package RSP::Extension::DataStore::Global;

use strict;
use warnings;

use RSP;
use base 'RSP::Extension::ConfigGroup';

sub exception_name {
  return "system.globalstore";
}

sub group_classname {
  return "DataStore";
}

sub providing_class {
  my $class = shift;
  $class->SUPER::providing_class(@_);
  return $class;
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  return {
    'globalstore' => {
      'types'  => sub {
	my $ns = shift;
	my @types = eval {
	  my $ds = RSP::Datastore->get_namespace( $class->providing_class_shortname, $ns );
	  $ds->types();
	};
	if ($@) {
	  print "got an error: $@\n";
	}
	return \@types;
      },
      'write'  => sub { 
	my $ns   = shift;
	my $type = lc( shift );
	my $ds   = RSP::Datastore->get_namespace( $ns );
	return $ds->write( $type, @_ );
       },
      'remove' => sub {
	my $ns   = shift;
	my $type = lc( shift );
	my $ds   = RSP::Datastore->get_namespace( $ns );
	return $ds->remove( $type, @_ );
       },
      'search' => sub {
	my $ns   = shift;
	my $type = lc( shift );
	my $ds   = RSP::Datastore->get_namespace( $ns );
	return $ds->query( $type, @_ );
       },
      'get'    => sub {
	my $ns   = shift;
	my $type = lc( shift );
	my $ds   = RSP::Datastore->get_namespace( $ns );
	return $ds->read( $type, @_ );
       }
    }
  };
}

1;
