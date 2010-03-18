package RSP::JSObject::Image;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::JSObject);

use Imager;
use Image::Math::Constrain;
use MIME::Types;
use File::Temp;

use RSP::JSObject::File;

has imager => (is => 'rw', isa => 'Imager', lazy_build => 1);
sub _build_imager {
    my ($self) = @_;
    my $img = Imager->new;
    $img->read( file => $self->file->fullpath ) or die $img->errstr;
    return $img;
}

has file => (is => 'rw', isa => 'Object', required => 1);
has mimetype => (is => 'rw', isa => 'MIME::Type', lazy_build => 1);
sub _build_mimetype {
    my ($self) = @_;
    return MIME::Type->new( type => $self->file->mimetype );
}

sub BUILDARGS {
    my ($self, $file) = @_;
    return { file => $file };
}

sub get_width {
    my ($self) = @_;
    return $self->imager->getwidth;
}

sub get_height {
    my ($self) = @_;
    return $self->imager->getheight;
}

sub flip_horizontal {
    my ($self) = @_;
    return $self->imager( $self->imager->flip( dir => 'h' ) );
}

sub flip_vertical {
    my ($self) = @_;
    return $self->imager( $self->imager->flip( dir => 'v' ) );
}

sub rotate {
    my ($self, $degrees) = @_;
    if(!defined $degrees) { die "no amount of degrees to rotate\n" }
    return $self->imager( $self->imager->rotate( degrees => $degrees ) );
}

sub scale {
    my ($self, $opts) = @_;
    my $x = $opts->{xpixels} // 0;
    my $y = $opts->{ypixels} // 0;
    return $self->imager( $self->imager->scale( constrain => Image::Math::Constrain->new( $x, $y ) ) );
}

sub crop {
    my ($self, $opts) = @_;
    return $self->imager( $self->imager->crop(%$opts) || die $self->imager->errstr );
}

sub save {
    my ($self, $new) = @_;
    if ( $new ) {
      my $temp = $self->{temp} = File::Temp->new();
      if (!$self->imager->write( file => $temp->filename, type => $self->mimetype->subType )) {
          die { message => $self->imager->errstr };
      }
      $temp->close;
      $self->file( RSP::JSObject::File->new( $temp->filename, "tmpimage" ) );
    } else {
      $self->imager->write( file => $self->file->fullpath, type => $self->mimetype->subType )
        or die { message => $self->imager->errstr };
    }
    return $self->file;
}

sub as_string {
  my $self = shift;
  my $args = { @_ };
  my $cnt;

  my $mimetype = MIME::Type->new( type => $args->{type} );
  $self->imager->write(type => $mimetype->subType, data=> \$cnt ) or die $self->imager->errstr;
  return $cnt;
}

__PACKAGE__->meta->make_immutable;
1;
