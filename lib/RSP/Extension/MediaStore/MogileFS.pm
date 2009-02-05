package RSP::Extension::MediaStore::MogileFS;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use MogileFS::Client;
use RSP::JSObject::MediaFile::Mogile;

use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;

  ##
  ## bind the mediafile type to the context.
  ##
  RSP::JSObject::MediaFile::Mogile->bind( $tx );

  return {
	  mediastore => {
			 write  => sub { $class->write( $tx, @_ ) },
			 remove => sub { $class->remove( $tx, @_ ) },
			 get    => sub { $class->get( $tx, @_ ) },
			}
	 };
}

##
## returns the domain of the transaction for mogilefs
##
sub domain_from_tx {
  my ($self, $tx) = @_;
  return $tx->hostname;
}

##
## returns a connection to mogilefs
##
sub getmogile {
  my $self = shift;
  my $tx   = shift;
  $tx->{mogile} ||= MogileFS::Client->new(
					  domain => $self->domain_from_tx( $tx ),
					  hosts  => [ split(',', RSP->config->{mogilefs}->{trackers}) ]
					 );
}

##
## writes a file to the media store.
##
sub write {
  my ($self, $tx, $name, $data) = @_;
  if (!defined($name)) { $tx->log("no name"); die "no name" }
  if (!defined($data)) { $tx->log("no data"); die "no data" }

  ## clear the cache so that we can be sure we are writing the
  ##   clean data.
  RSP::JSObject::MediaFile->clearcache( $tx, $name );

  my $mog = eval { $self->getmogile( $tx ) };
  if ($@ || !$mog) {
    $tx->log("an error occurred when trying to get a mogile handle: $@");
    die "an error occurred when trying to get a mogile handle: $@";
  }
  eval {
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
  my ($self, $tx, $name) = @_;
  my $file = $self->get( $tx, $name );
  $file->remove();
}

##
## gets a file from the media store
##
sub get {
  my ($self, $tx, $name) = @_;
  if (!defined($name)) { $tx->log("no name"); die "no name" }

  my $mog   = eval { $self->getmogile( $tx ) };
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
    return RSP::JSObject::MediaFile->new( $mog, $tx, $name, \@paths );
  } else {
    return undef;
  }
}

1;
