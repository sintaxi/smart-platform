package RSP::Host;

use strict;
use warnings;

use Cwd;
use File::Spec;
use base 'Class::Accessor::Chained';

__PACKAGE__->mk_accessors(qw( hostname ));

##
## returns a newly constructed host object.
## take the hostname as a parameter.
##
sub new {
  my $class = shift;
  my $tx    = shift || die "no transaction";
  my $self  = {};

  bless $self, $class;

  $self->hostname( $tx->hostname );

  return $self;
}

##
## op thresholds...
##
sub op_threshold {
  my $self = shift;
  $self->{oplimit} ||= RSP->config->{ 'host:'.$self->hostname }->{oplimit} || RSP->config->{rsp}->{oplimit} || 100_000;
}

##
## should report consumption?
##
sub should_report_consumption {
  my $self = shift;
  if ( RSP->config->{ 'host:'.$self->hostname }->{ noconsumption } ) {
    return 0;
  }
  return 1;
}

##
## lots of things in RSP need a namespace for isolation,
##   this method returns the namespace for this host
##
sub namespace {
  my $self = shift;
  if (! $self->{namespace} ) {
    $self->{namespace} = join(".", split(/\./, $self->{namespace}));
  }
  return $self->{namespace};
}

##
## this is the name of the function that we call in the JavaScript
##  context to start the transaction processing
##
sub entrypoint {
  return "main";
}

##
## returns a list of extensions that need
## to be built into the client.  This is
## a list of classnames.
##
sub extensions {
  my $self = shift;
  my $global = RSP->config->{_}->{extensions} || '';
  my $host   = RSP->config->{ 'host:'.$self->hostname }->{extensions} || '';

  my @exts = map {
    s/\s//g;
    'RSP::Extension::' . $_ 
  } (
     split(/,/, $global),
     split(/,/, $host)
    );

  return @exts;
}

##
## returns the file that bootstraps the server
##
sub bootstrap_file {
  my $self = shift;
  File::Spec->catfile( $self->code, "bootstrap.js" );
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
  my $meth = $type;
  File::Spec->catfile( $self->$meth, $path );
}

##
## returns the root of the code directory
##
sub code {
  my $self = shift;
  File::Spec->catfile( $self->root, "js" );
}

##
## actual_host returns the real hostname of the thing.  This
##  lets us escape from www.foo and foo problems by allowing
##  an 'alternate' name
##
sub actual_host {
  my $self = shift;
  my $cnf  = RSP->config->{ 'host:'.$self->hostname };
  if ($cnf && exists $cnf->{alternate}) {
    return $cnf->{alternate};
  }
  return $self->hostname;
}

##
## returns the root of the web directory
##
sub web {
  my $self = shift;
  File::Spec->catfile( $self->root, "web" );
}

##
## returns the root of the host
##
sub root {
  my $self = shift;
  my $host_root = RSP->config->{rsp}->{hostroot};
  if ( substr( $host_root, 0, 1 ) eq '/' ) {
    my $root = File::Spec->catfile( $host_root, $self->actual_host );
    return $root;
  } else {
    my $root = File::Spec->catfile( RSP->root, $host_root, $self->actual_host );
    return $root;
  }
}

##
## return the access log for this host
##
sub access_log {
    my $self = shift;
    File::Spec->catfile( $self->root, qw(log access_log) );
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
