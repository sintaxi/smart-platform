package RSP::Transaction;

use strict;
use warnings;

use File::Spec;

sub start {
  my $class = shift;
  my $cx    = shift or die "no context provided";
  my $req   = shift or die "no request provided";
  my $turi = URI->new('http://' . lc($req->header('Host')) . '/');
  my $self = { host => $turi->host, request => $req, context => $cx };
  bless $self => $class;
  $self->import_extensions();
  return $self;
}

sub run {
  my $self = shift;
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
  my $result = $self->{context}->call('main');
  if ($@) {
    die $@;
  }
  return $result;
}

sub end {
  my $self = shift;
  $self = undef;
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
  return File::Spec->catfile(
    $self->hostroot,
    RSP->config->{hosts}->{WebRoot},
  );
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
  return File::Spec->catfile(
    RSP->config->{git}->{Root},
    ( RSP->config->{ $self->{host} }->{git} ) ? 
      RSP->config->{ $self->{host} }->{git} :
      'core'
  );
}

sub dbfile {
  my $self = shift;
  return File::Spec->catfile(
    $self->dbroot,
    RSP->config->{db}->{File}
  );
}

1;
