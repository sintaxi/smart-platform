package RSP::Datastore::Namespace::MySQL;

use strict;
use warnings;

use RSP;
use RSP::Transaction;

use DBI;
use JSON::XS;
use SQL::Abstract;
use Set::Object;
use Carp qw( confess cluck );
use Scalar::Util::Numeric qw( isnum isint isfloat );
use Digest::MD5 qw( md5_hex );

use base 'RSP::Datastore::Namespace';

sub create {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->new;
  $self->namespace( md5_hex($ns) );
  my $host = RSP->config->{mysql}->{host};
  $self->conn( DBI->connect_cached("dbi:mysql:host=$host", RSP->config->{mysql}->{username}, RSP->config->{mysql}->{password}) );
  $self->conn->do("create database " . $self->namespace);
  $self->conn->do("use " . $self->namespace);

  $self->cache( RSP::Transaction->cache( $ns ) );
  return $self;
}

sub connect {
  my $class = shift;
  my $ns    = shift;
  my $self  = $class->new;
  my $db    = md5_hex($ns);
  $self->namespace( $db );
  my $host = RSP->config->{mysql}->{host};
  $self->conn( DBI->connect_cached("dbi:mysql:host=$host;database=$db", RSP->config->{mysql}->{username}, RSP->config->{mysql}->{password}) );

  if (!$self->conn) {
    ## if we couldn't get a connection, chances are it's because
    ## we're missing the database, lets create one and see if that resolves it...
    $self = $class->create( $ns );
  }

  $self->cache( RSP::Transaction->cache( $ns ) );

  return $self;
}

1;
