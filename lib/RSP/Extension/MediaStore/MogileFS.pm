package RSP::Extension::MediaStore::MogileFS;

use strict;
use warnings;

use Scalar::Util qw( blessed );

use MogileFS::Client;
use RSP::JSObject::MediaFile;

use base 'RSP::Extension';

sub provides {
  my $class = shift;
  my $tx    = shift;

  RSP::JSObject::MediaFile->bind( $tx );

  return {
	  mediastore => {
			 write  => sub { $class->write( $tx, @_ ) },
			 remove => sub { $class->remove( $tx, @_ ) },
			 get    => sub { $class->get( $tx, @_ ) },
			}
	 };
}

sub domain_from_tx {
  my ($self, $tx) = @_;
  return $tx->hostname;
}

sub getmogile {
  my $self = shift;
  my $tx   = shift;
  $tx->{mogile} ||= MogileFS::Client->new(
					  domain => $self->domain_from_tx( $tx ),
					  hosts  => [ split(',', RSP->config->{mogilefs}->{trackers}) ]
					 );
}

sub write {
  my ($self, $tx, $name, $data) = @_;
  if (!defined($name)) { $tx->log("no name"); die "no name" }
  if (!defined($data)) { $tx->log("no data"); die "no data" }
  RSP::JSObject::MediaFile->clearcache( $tx, $name );
  eval {
    my $mog = $self->getmogile( $tx );
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

sub remove {
  my ($self, $tx, $name) = @_;
  my $file = $self->get( $tx, $name );
  $file->remove();
}

sub get {
  my ($self, $tx, $name) = @_;
  if (!defined($name)) { $tx->log("no name"); die "no name" }

  my $mog   = eval { $self->getmogile( $tx ) };
  if ($@) {
    $tx->log("an error occurred when trying to get a mogile handle: $@");
    die "an error occurred when trying to get a mogile handle: $@";
  }
  my @paths = eval {
    my @paths = $mog->get_paths( $name, { noverify => 1 });
  };
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
