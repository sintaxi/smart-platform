package RSP::Host;

use strict;
use warnings;

use File::Spec;
use base 'Class::Accessor::Chained';

__PACKAGE__->mk_accessors(qw( hostname ));

##
## returns a newly constructed host object.
## take the hostname as a parameter.
##
sub new {
  my $class = shift;
  my $hostname = shift || die "no hostname";
  if ($hostname =~ /:/) {
    $hostname =~ s/:.+$//;
  }

  bless { hostname => $hostname }, $class;  
}

##
## returns a list of extensions that need 
## to be built into the client.  This is 
## a list of classnames.
##
sub extensions {
  my $self = shift;
  return (
    'RSP::Extension::HTTPRequest',
    'RSP::Extension::JSONEncoder',
    'RSP::Extension::FileSystem',
    'RSP::Extension::OpenId',
    'RSP::Extension::UUID',
    'RSP::Extension::Import',
    'RSP::Extension::Console',
    'RSP::Extension::Template',
    'RSP::Extension::MD5',
  );
}

##
## returns the file that bootstraps the server
##
sub bootstrap_file {
  my $self = shift;
  File::Spec->catfile( $self->coderoot, "bootstrap.js" );
}

##
## gets a file from either the webroot or the coderoot,
## pass in the type (web or code) followed by the file's path
## and get the full path back.
##
sub file {
  my $self = shift;
  my $type = shift;
  my $path = shift;
  my $meth = $type . "root";
  File::Spec->catfile( $self->$meth, $path );
}

##
## returns the root of the code directory
##
sub coderoot {
  my $self = shift;
  File::Spec->catfile( $self->hostroot, "js" );
}

##
## actual_host returns the real hostname of the thing.  This
##  lets us escape from www.foo and foo problems by allowing
##  an 'alternate' name
##
sub actual_host {
  my $self = shift;  
  return RSP->config->{$self->hostname}->{alternate} || $self->hostname;  
}

##
## returns the root of the web directory
##
sub webroot {
  my $self = shift;
  File::Spec->catfile( $self->hostroot, "web" );
}

##
## returns the root of the host
##
sub hostroot {
  my $self = shift;
  my $root = RSP->config->{rsp}->{hostroot};
  File::Spec->catfile( $root, $self->actual_host );
}

##
## returns the size of memory to allocate before
##  we garbage collect in the JS VM.
##
sub alloc_size {
  my $self = shift;
  return ( 1024 ** 2 ) * 2;
}


1;
