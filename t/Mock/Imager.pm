package Imager;

use unmocked 'Moose';

our $READ_FILE;
sub read {
    my ($self, %opts) = @_;
    $READ_FILE = $opts{file};
}

our $HEIGHT;
sub getheight { return $HEIGHT }

our $WIDTH;
sub getwidth { return $WIDTH }

our $FLIP_DIRECTION;
sub flip {
    my ($self, %opts) = @_;
    $FLIP_DIRECTION = $opts{dir};
    return $self;
}

our $ROTATE_DEGREES;
sub rotate {
    my ($self, %opts) = @_;
    $ROTATE_DEGREES = $opts{degrees};
    return $self;
}

our $SCALE;
sub scale {
    my ($self, %opts) = @_;
    $SCALE = $opts{constrain};
    return $self;
}

our $CROP;
sub crop {
    my ($self, %opts) = @_;
    $CROP = \%opts;
    return $self;
}

our $SAVE_FILE;
our $SAVE_MIME;
our $DATA;
sub write {
    my ($self, %opts) = @_;
    $SAVE_FILE = $opts{file};
    $SAVE_MIME = $opts{type};
    my $cnt = $opts{data};
    $$cnt = $DATA;
    1;
}

1;
