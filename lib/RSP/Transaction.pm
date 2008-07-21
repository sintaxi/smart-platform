package RSP::Transaction;

use strict;
use warnings;
use JavaScript;

use Module::Load;
use Time::HiRes qw( gettimeofday tv_interval );
use File::Spec;

sub start {
  my $class = shift;
  my $rt    = JavaScript::Runtime->new;
  my $cx    = $rt->create_context;
  my $req   = shift or die "no request provided";
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
  $self->logp( $self->profile('transaction'), "%s on " . $self->{request}->uri . " took %s");
  return $result;
}

sub end {
  my $self = shift;
  $self->logp($self->{ops}, "opcount", "%s was %s");
  $self = undef;
}

sub profile {
  my $self = shift;
  my $type = shift;
  if (!$self->{profile}->{$type}) {
    $self->{profile}->{$type}->{start} = [gettimeofday];
  } else {
    return (tv_interval( delete $self->{profile}->{$type}->{start} ), $type);
  }
}

sub logp {
  my $self = shift;
  my $num  = shift;
  my $type = shift;
  my $mesg = shift;
  if ( !$mesg ) {
    $mesg = "stat of type %s was %s";
  }
  $self->log( sprintf($mesg, $type, $num) );
}

sub log {
  my $self = shift;
  my $mesg  = shift;
  my $fmsg  = sprintf("[%s (%s)] %s\n", $self->{host}, $$, $mesg);
  if (!RSP->config->{_}->{LogFile}) {
    print STDERR $fmsg;
  }
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
