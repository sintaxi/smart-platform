#    This file is part of the RSP.
#
#    The RSP is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    The RSP is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with the RSP.  If not, see <http://www.gnu.org/licenses/>.
package RSP::Transaction;

use strict;
use warnings;
use JavaScript;

use Module::Load;
use Time::HiRes qw( gettimeofday tv_interval );
use File::Spec;
use Hash::Merge::Simple;

sub start {
  my $class = shift;
  my $req   = shift or die "no request provided";
  my $hints = shift || {};
  my $rt    = JavaScript::Runtime->new;
  my $cx    = $rt->create_context;

  $cx->set_version("1.7") if $cx->can("set_version");
#  if ( $cx->can("toggle_options") ) {
    print "WE ARE JITTING\n";
    $cx->toggle_options( "jit" );
#  }

  my $turi = URI->new('http://' . lc($req->header('Host')) . '/');

  my $self = { ops => 0, host => $turi->host, request => $req, context => $cx };
  bless $self => $class;

  $self->{hints} = $hints;

  $rt->set_interrupt_handler( sub {
    $self->{ops}++;
    return 1;
  } );

  $self->import_extensions();
  return $self;
}

sub host {
  my $self = shift;
  return $self->{host};
}

sub run {
  my $self = shift;
  my $func = shift || 'main';
  
  $self->profile('transaction');

  my $bs = File::Spec->catfile(
    $self->jsroot,
    RSP->config->{hosts}->{JSBootstrap}    
  );
  $self->{context}->eval_file( $bs );
  if ($@) {
    $self->log("bootstrapping $bs failed: $@");
    warn("bootstrapping $bs failed: $@");
    die $@;
  }
  my $result = $self->{context}->call($func);
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
    $self->logger->send({ host => $self->{host}, request => $self->{request}->uri->path, elapsed => $intv, type => $type }, 'profiling');
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
    { count => $num, type => $type, host => $self->{host}, request => $self->{request}->uri->path }, "billing"
  );
}

sub log {
  my $self = shift;
  my $mesg  = shift;
  my $fmsg  = sprintf("[%s (%s)] %s\n", $self->{host}, $$, $mesg);
  $self->logger->send($fmsg, 'log');
}

##
## private, not in public docs.  This loads the extensions for a particular
## host into the JavaScript environment.
##
sub import_extensions {
  my $self  = shift;
  my $extension_list = RSP->config->{_}->{extensions};
  if (exists(RSP->config->{ $self->{host} }) && exists(RSP->config->{ $self->{host} }->{extensions})) {
    $extension_list = join( ",", $extension_list, RSP->config->{$self->{host}}->{extensions});  
  }
  my @extensions_to_load = split(',', $extension_list);
  my @exts   = map {
      $_ =~ s/\s//g;
      'RSP::Extension::' . $_;
  } @extensions_to_load;
  my $system = {};
  foreach my $ext ( @exts ) {
   eval { 
     $system = Hash::Merge::Simple::merge(
          $system,
          { $self->import_extension( $ext ) }
      );
   };
  }
  $self->{context}->bind_value( 'system' => $system );
}

##
## This is not documented in the public documentation.
## It imports a single extension into the JavaScript environment.
##
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

=head1 NAME

RSP::Transaction - processing of a single request in the RSP

=head1 SYNOPSIS

  use RSP::Transaction

  my $rspt = RSP::Transaction->start( $http_request );
  my $result = $rspt->run;
  $rspt->end;
  
=head1 DESCRIPTION

The C<RSP::Transaction> class is where most of the action happens when
a request to the RSP arrives.  It is responsible for routing the request,
composing the JavaScript environment, logging the billing information, and
any other host-specific details that may need to be provided to any extensions.

=head1 CONSTRUCTOR

=over 4

=item RSP::Transaction start( HTTP::Request aRequest )

When RSP::Transaction constructs the request it builds a JavaScript environment
that is custom to the request. It returns an RSP::Transaction object that you
can do whatever you like with.  Most likely you'll want to call the C<run>
method upon it.

=back

=head1 METHODS

=over 4

=item Thing run([String functionName])

Passes the request into the JavaScript environment, by calling functionName, if 
specified, or C<main()>. If the JavaScript environment returns successfully, any
return value from it is returned as the result.  Any exceptions that are thrown
in the JavaScript environment are re-thrown in this method.  You'll need to
catch them, and process them as you see fit.

=item profile( String aThing )

The C<profile> method provides profiling for particular element of a request
named in aThing. The first time the method is called with a particular string
a timer starts, the second time the timer is stopped, and the details logged.

=item log_billing( Integer aCount, String aType[, String mesg ])

The C<log_billing> method provides information to the billing engine.  For example
if you wanted to log op count information, you'd do something like:

  $tx->log_billing( $number_of_ops, "opcount" );

The mechanism that is used to process the data is unimportant to this method.

=item String hostroot()

Uses the configuration setting Root in the hosts group of the config file, as
well as the original request to provide a path to root of a host.

=item String jsroot()

Uses the configuration setting JSRoot in the hosts group of the config file to
provide a path to the root of the javascript for a particular host.

=item String webroot()

Uses the configuration setting WebRoot in the hosts group of the config file to
provide a path to the root of the web-related files for a particular host.

=item String dbroot()

Uses the configuration setting Root in the db group of the config file to provide
a path to the directory where the hosts databse is stored.

This will be deprecated in future releases.

=item String gitroot()

Uses the configuration setting Root in the git group of the config file to provide
a path to the git repository for a given host.

=item String dbfile()

Uses the configuration setting File in the db group of the config file to provide
a filename for the hosts datastore.

This will be deprecated in future releases.

=back

=head1 SEE ALSO

=over 4

=item RSP::Extension

=item RSP::Config

=back

=head1 AUTHOR

James A. Duncan <james@reasonablysmart.com>

=head1 LICENSE


This file is part of the RSP.

The RSP is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The RSP is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the RSP.  If not, see <http://www.gnu.org/licenses/>.

=cut
  
