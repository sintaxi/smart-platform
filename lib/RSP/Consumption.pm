package RSP::Consumption;

use strict;
use warnings;

use JSON::XS qw();

use base 'Class::Accessor::Chained';
RSP::Consumption->mk_accessors(qw( count name uri host ));

sub new {
  my $class = shift;
  my $self  = {};
  bless($self, $class)->init(@_);
}

sub init {
  my $self = shift;
  return $self;
}

sub as_json {
  my $self = shift;
  return JSON::XS::encode_json( { %$self } );
}

1;

