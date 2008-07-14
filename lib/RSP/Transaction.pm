package RSP::Transaction;

use strict;
use warnings;

use File::Spec;

my $self = undef;

sub start {
  my $class = shift;
  my $cx    = shift or die "no context provided";
  my $req   = shift or die "no request provided";
  my $turi = URI->new('http://' . lc($req->header('Host')) . '/');
  $self = { host => $turi->host, request => $req, context => $cx };
  bless $self => $class;
  $class->import_extensions();
  return $self;
}

sub run {
  my $class = shift;
  my $bs = File::Spec->catfile(
    RSP->config->{server}->{Root},
    RSP->config->{hosts}->{Root},
    $self->{host},
    RSP->config->{hosts}->{JSRoot},
    RSP->config->{hosts}->{JSBootstrap}    
  );
  $self->{context}->eval_file( $bs );
  if ($@) {
    $self->log("bootstrapping $bs failed: $@");
    die $@;
  }
  return $self->{context}->call('main');
}

sub end {
  $self = undef;
}

sub log {
  my $class = shift;
  my $mesg  = shift;
  my $fmsg  = sprintf("[%s (%s)] %s\n", $self->{host}, $$, $mesg);
  if (!RSP->config->{_}->{LogFile}) {
    print STDERR $fmsg;
  }
}

sub import_extensions {
  my $class  = shift;
  my @exts   = map {
    $_ =~ s/\s//g;
    'RSP::Extension::' . $_;
  } split(',', RSP->config->{_}->{extensions});
  foreach my $ext ( @exts ) {
    $self->import_extension( $ext );
  }
}

sub import_extension {
  my $class  = shift;
  my $ext    = shift; ## Extension class name
  eval {
    Module::Load::load( $ext );
  };
  if ($@) {
    $self->log("attempt to load extension $ext failed: $@");
  } else {
    $self->{context}->bind_value( $ext->provide( $self ) );
  }
}

1;
