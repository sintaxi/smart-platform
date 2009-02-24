package RSP::Error;

use strict;
use warnings;

use base 'RSP::JSObject';
use Scalar::Util qw( blessed );
use overload q{""} => \&as_string, fallback => 1;

sub jsclass {
  return 'PlatformError';
}

sub properties {
  return {
	  'message' => {
			'getter' => sub { return $_[0]->{message} }
		       },
	  'fileName' => {
			 'getter' => sub { return $_[0]->{fileName} }
			},
	  'lineNumber' => {
			   'getter' => sub { return $_[0]->{lineNumber} }
			  }
	 };
}

sub methods {
  return {
	  'toString' => sub { my $self = shift; return $self->as_string; }
	 };
}

sub new {
  my $class = shift;
  my $mesg  = shift;
  my $tx    = shift;

  my $obj;
  if (blessed( $mesg )) {
    $obj = $mesg;
    if ( $tx ) {
      my $codepath = $tx->host->root;
      $obj->{fileName} =~ s/$codepath//;
    }
  } else {
    chomp $mesg;
    my ($package, $filename, $line) = caller(1);
    if ( $package->can('exception_name') ) {
      $filename = $package->exception_name;
    }
    $obj = { message => $mesg, fileName => $filename, lineNumber => $line };
  }
  return bless $obj, $class;
}

sub throw {
  my $class = shift;
  my $mesg  = shift;

  if ( blessed( $class ) ) {
    die $class;
  } else {
    die $class->new( $mesg );
  }
}

sub as_string {
  my $self = shift;
  if ( $self->{fileName} && $self->{lineNumber}) {
    return "$self->{message} in file $self->{fileName} at line $self->{lineNumber}";
  } elsif ( $self->{fileName} && !$self->{lineNumber} ) {
    return "$self->{message} in file $self->{fileName}";
  } else {
    return $self->{message};
  }
}

1;

