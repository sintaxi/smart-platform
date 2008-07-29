package RSP::Transaction;

use strict;
use warnings;
use JavaScript;

use Module::Load;
use Time::HiRes qw( gettimeofday tv_interval );
use File::Spec;

sub start {
  my $class = shift;
  my $req   = shift or die "no request provided";

  my $rt    = JavaScript::Runtime->new;
  my $cx    = $rt->create_context;
  $cx->set_version("1.7") if $cx->can("set_version");
  my $turi = URI->new('http://' . lc($req->header('Host')) . '/');

  my $self = { ops => 0, host => $turi->host, request => $req, context => $cx };
  bless $self => $class;

  $self->profile('transaction');

  $rt->set_interrupt_handler( sub {
    $self->{ops}++;
    return 1;
  } );

  $self->import_extensions();
  return $self;
}

sub run {
  my $self = shift;
  my $bs = File::Spec->catfile(
    $self->jsroot,
    RSP->config->{hosts}->{JSBootstrap}    
  );
  $self->{context}->eval_file( $bs );
  if ($@) {
    $self->log("bootstrapping $bs failed: $@");
    die $@;
  }
  my $result = $self->{context}->call('main');
  if ($@) {
    die $@;
  }
  
  $self->profile('transaction');
  return $result;
}

sub end {
  my $self = shift;
  $self->log_billing($self->{ops}, "opcount", "%s was %s");
  $self = undef;
}

sub logger {
  my $self = shift;
  if (!$self->{logpackage}) {
    $self->{logpackage} = RSP->config->{server}->{LogPackage} || 'RSP::Queue::Fake';
    eval {
      Module::Load::load( $self->{logpackage} );    
    };
    if ($@) { warn("could not load module $self->{logpackage}: $@") }
  }
  return $self->{logpackage};
}

sub profile {
  my $self = shift;
  my $type = shift;
  if (!$self->{profile}->{$type}) {
    $self->{profile}->{$type}->{start} = [gettimeofday];
  } else {
    my $intv = tv_interval( delete $self->{profile}->{$type}->{start} );
    $self->logger->send({ host => $self->{host}, request => $self->{request}->uri->as_string, elapsed => $intv, type => $type }, 'profiling');
  }
}

### log profiling information (for example, op counts and 
sub log_billing {
  my $self = shift;
  my $num  = shift;
  my $type = shift;
  my $mesg = shift;
  
  if (RSP->config->{$self->{host}}->{NoBilling}) { return; }
  
  $self->logger->send(
    { count => $num, type => $type, host => $self->{host}, request => $self->{request}->uri->as_string }, "billing"
  );
}

sub log {
  my $self = shift;
  my $mesg  = shift;
  my $fmsg  = sprintf("[%s (%s)] %s\n", $self->{host}, $$, $mesg);
  $self->logger->send($fmsg, 'log');
}

sub import_extensions {
  my $self  = shift;
  my @exts   = map {
    $_ =~ s/\s//g;
    'RSP::Extension::' . $_;
  } split(',', join(",",
     RSP->config->{_}->{extensions},
     ( RSP->config->{ $self->{host} } ) ? RSP->config->{ $self->{host} }->{extensions} : () 
  ));
  my $system = {};
  foreach my $ext ( @exts ) {
    my %hash = $self->import_extension( $ext );
    foreach my $key ( keys %hash ) {
      $system->{ $key } = $hash{$key};
    }
  }
  $self->{context}->bind_value( 'system' => $system );
}

sub import_extension {
  my $self  = shift;
  my $ext    = shift; ## Extension class name
  eval {
    Module::Load::load( $ext );
  };
  if ($@) {    
    $self->log("attempt to load extension $ext failed: $@");
  } else {
    return $ext->provide( $self );
  }
}

sub hostroot {
  my $self = shift;
  my $hostroot = RSP->config->{hosts}->{Root};
  if ( $hostroot =~ m!^/! ) {
    return File::Spec->catfile(
      $hostroot,
      $self->{host},
    );
  } else {
    return File::Spec->catfile(
      RSP->config->{server}->{Root},
      RSP->config->{hosts}->{Root},
      $self->{host},
    ); 
  }
}

sub jsroot {
  my $self = shift;
  return File::Spec->catfile(
    $self->hostroot,
    RSP->config->{hosts}->{JSRoot},
  );
}

sub webroot {
  my $self = shift;
  my $file = File::Spec->catfile(
    $self->hostroot,
    RSP->config->{hosts}->{WebRoot},
  );
  return $file;
}


sub dbroot {
  my $self = shift;
  my $dbroot = RSP->config->{db}->{Root};
  if ( $dbroot =~ m!^/! ) {
    return File::Spec->catfile(
      $dbroot,
      $self->{host},
    );
  } else {
    return File::Spec->catfile(
      RSP->config->{server}->{Root},
      RSP->config->{db}->{Root},
      $self->{host},
    ); 
  }
}

sub gitroot {
  my $self = shift;
  return RSP->config->{git}->{Root};
}

sub dbfile {
  my $self = shift;
  return File::Spec->catfile(
    $self->dbroot,
    RSP->config->{db}->{File}
  );
}

1;
