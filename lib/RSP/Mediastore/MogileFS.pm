package RSP::Mediastore::MogileFS;

use Moose;
use namespace::autoclean;
use Scalar::Util qw( blessed );

use MogileFS::Admin;
use MogileFS::Client;
use RSP::JSObject::MediaFile::Mogile;

has namespace => (is => 'ro', isa => 'Str', required => 1);
has namespace_sum => (is => 'ro', isa => 'Str', lazy_build => 1);
has trackers => (is => 'ro', isa => 'ArrayRef', required => 1);

##
## returns the domain of the transaction for mogilefs
##
sub domain_from_tx_and_type {
  my ($self, $type) = @_;
  return join(':', $self->namespace, $type);
}

##
## returns a connection to mogilefs
##
sub getmogile {
  my $self = shift;
  my $type = shift;
  MogileFS::Client->new(
      domain => $self->domain_from_tx_and_type( $type ),
      hosts  => $self->trackers,
  );
}

##
## returns an administrative connection to mogilefs
##
my $MOGILE_ADMIN;
sub getmogile_adm {
    my $self = shift;
    $MOGILE_ADMIN ||= do {
        MogileFS::Admin->new(
            hosts => $self->trackers,
        );
    };
    return $MOGILE_ADMIN;
}

##
## writes a file to the media store.
##
sub write {
  my ( $self, $type, $name, $data ) = @_;
  eval { $self->_write( $type, $name, $data ) };
  if ($@) {
    if ( $@ =~ /unreg_domain/ ) {
      my $domain = $self->domain_from_tx_and_type( $type );
      my $adm = $self->getmogile_adm( );
      if (!$adm->create_domain( $domain )) {
	die "could not register unregistered domain: " . $adm->errstr;
      } else {
	$self->_write( $type, $name, $data );
      }
    } else {
      die $@;
    }
  }
  return 1;
}

sub _write {
  my ($self, $type, $name, $data) = @_;
  if (!defined($name)) { 
        #$tx->log("no name"); 
        die "no name" 
    }
  if (!defined($data)) { 
      #$tx->log("no data"); 
      die "no data" 
  }

  ## clear the cache so that we can be sure we are writing the
  ##   clean data.
  RSP::JSObject::MediaFile::Mogile->clearcache( $name );

  my $mog = eval { $self->getmogile( $type ) };
  if ($@ || !$mog) {
      #$tx->log("an error occurred when trying to get a mogile handle: $@");
    die "an error occurred when trying to get a mogile handle: $@";
  }
  eval {
    ## if we have a file object instead of just some data...
    if ( blessed( $data ) ) {
      if ( !$mog->store_file($name, undef, $data->fullpath) ) {
          #$tx->log("an error occurred when attempting to write " . $data->filename . " " . $mog->errcode);
	die "an error occurred when attempting to write " . $data->filename . " " . $mog->errcode;
      }
    } else {
      if (!$mog->store_content($name, undef, $data)) {
          #$tx->log("an error occurred when attempting to write $name (" . $mog->errcode . ")");
	die "an error occurred when attempting to write $name (" . $mog->errcode . ")";
      }
    }
  };
  if ($@) {
      #$tx->log($@);
    die $@;
  }
  return 1;
}

##
## removes a file from the media store
##
sub remove {
  my ($self, $type, $name) = @_;
  my $file = $self->get( $type, $name );
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
  my ($self, $type, $name) = @_;
  if (!defined($name)) { 
      #$tx->log("no name"); 
      die "no name" 
  }

  my $mog   = eval { $self->getmogile( $type ) };
  if ($@ || !$mog) {
      #$tx->log("an error occurred when trying to get a mogile handle: $@");
    die "an error occurred when trying to get a mogile handle: $@";
  }
  my @paths = eval { $mog->get_paths( $name, { noverify => 1 }) };
  if ($@) {
      #$tx->log("an error occurred when trying to read $name: " . $mog->errcode);
    die "an error occurred when trying to read $name: " . $mog->errcode;
  }
  if (@paths) {
    return RSP::JSObject::MediaFile::Mogile->new( $mog, $name, \@paths );
  } else {
      #$tx->log("didn't get any paths back from mogile for file '$name'");
    return undef;
  }
}

__PACKAGE__->meta->make_immutable;
1;
