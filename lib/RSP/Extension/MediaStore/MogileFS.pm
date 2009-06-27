package RSP::Extension::MediaStore::MogileFS;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use MogileFS::Admin;
use MogileFS::Client;
use RSP::JSObject::MediaFile::Mogile;

use base 'RSP::Extension::MediaStore';

##
## we should bind this class...
##
sub bind_class {
  return 'RSP::JSObject::MediaFile::Mogile';
}

##
## returns the domain of the transaction for mogilefs
##
sub domain_from_tx_and_type {
  my ($self, $tx, $type) = @_;
  return join(':', $tx->hostname, $type);
}

##
## returns a connection to mogilefs
##
sub getmogile {
  my $self = shift;
  my $tx   = shift;
  my $type = shift;
  MogileFS::Client->new(
      domain => $self->domain_from_tx_and_type( $tx, $type ),
      hosts  => [ split(',', RSP->config->{mogilefs}->{trackers}) ]
  );
}

##
## returns an administrative connection to mogilefs
##
sub getmogile_adm {
  my $self = shift;
  my $tx   = shift;
  $tx->{mogile_adm} ||= MogileFS::Admin->new(
					 hosts => [ split(',', RSP->config->{mogilefs}->{trackers}) ]
					);
}

##
## writes a file to the media store.
##
sub write {
  my ( $self, $tx, $type, $name, $data ) = @_;
  eval { $self->_write( $tx, $type, $name, $data ) };
  if ($@) {
    if ( $@ =~ /unreg_domain/ ) {
      my $domain = $self->domain_from_tx_and_type( $tx, $type );
      my $adm = $self->getmogile_adm( $tx );
      if (!$adm->create_domain( $domain )) {
	die "could not register unregistered domain: " . $adm->errstr;
      } else {
	$self->_write( $tx, $type, $name, $data );
      }
    } else {
      die $@;
    }
  }
  return 1;
}

sub _write {
  my ($self, $tx, $type, $name, $data) = @_;
  if (!defined($name)) { $tx->log("no name"); die "no name" }
  if (!defined($data)) { $tx->log("no data"); die "no data" }

  ## clear the cache so that we can be sure we are writing the
  ##   clean data.
  $self->bind_class->clearcache( $tx, $name );

  my $mog = eval { $self->getmogile( $tx, $type ) };
  if ($@ || !$mog) {
    $tx->log("an error occurred when trying to get a mogile handle: $@");
    die "an error occurred when trying to get a mogile handle: $@";
  }
  eval {
    ## if we have a file object instead of just some data...
    if ( blessed( $data ) ) {
      if ( !$mog->store_file($name, undef, $data->fullpath) ) {
	$tx->log("an error occurred when attempting to write " . $data->filename . " " . $mog->errcode);
	die "an error occurred when attempting to write " . $data->filename . " " . $mog->errcode;
      }
    } else {
      if (!$mog->store_content($name, undef, $data)) {
	$tx->log("an error occurred when attempting to write $name (" . $mog->errcode . ")");
	die "an error occurred when attempting to write $name (" . $mog->errcode . ")";
      }
    }
  };
  if ($@) {
    $tx->log($@);
    die $@;
  }
  return 1;
}

##
## removes a file from the media store
##
sub remove {
  my ($self, $tx, $type, $name) = @_;
  my $file = $self->get( $tx, $type, $name );
  eval { $file->remove(); };
  if ($@) {
    die $@;
  }
  return 1;
}

##
## gets a file from the media store
##
sub get {
  my ($self, $tx, $type, $name) = @_;
  if (!defined($name)) { $tx->log("no name"); die "no name" }

  my $mog   = eval { $self->getmogile( $tx, $type ) };
  if ($@ || !$mog) {
    $tx->log("an error occurred when trying to get a mogile handle: $@");
    die "an error occurred when trying to get a mogile handle: $@";
  }
  my @paths = eval { $mog->get_paths( $name, { noverify => 1 }) };
  if ($@) {
    $tx->log("an error occurred when trying to read $name: " . $mog->errcode);
    die "an error occurred when trying to read $name: " . $mog->errcode;
  }
  if (@paths) {
    return $self->bind_class->new( $mog, $tx, $name, \@paths );
  } else {
    $tx->log("didn't get any paths back from mogile for file '$name'");
    return undef;
  }
}

1;
