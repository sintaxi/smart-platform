#!/usr/bin/perl

use strict;
use warnings;

use RSP;
use POSIX;
use Spread;
use JSON::XS;
use DateTime;
use RSP::ObjectStore;
use RSP::Queue::Client;

my $FLUSH_AT = 10;

my $coder = JSON::XS->new->allow_nonref;
$0 = "RSP Billing Collation";

if ( RSP->config->{server}->{User} ) {
   {
      my ($name,$passwd,$gid,$members) = getgrnam( RSP->config->{server}->{Group} );
      if ($gid) {
        POSIX::setgid( $gid );
        if ($!) { warn "setgid: $!" }
      } else {
        die "unknown group RSP->config->{server}->{User}";
      }
   }
    {
      my ($name,$passwd,$uid,$gid, $quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam( RSP->config->{server}->{User} );
      if ($uid) {
        POSIX::setuid( $uid );
        if ($!) { warn "setuid: $!" }
      } else {
        die "unknown user RSP->config->{server}->{User}";
      }
   }
}


my $hosts = {};

RSP::Queue::Client->listen( "billing", sub {
  my ($mbox, $private_group, $service_type, $sender, $groups, $mess_type, $endian, $message) = @_;
  if ( $service_type & Spread::MEMBERSHIP_MESS ) {
    my $members = scalar(@$groups);
    print "There are now $members member(s) of the $sender group\n";
  } else {
    my $os = RSP::ObjectStore->new( RSP->config->{server}->{BillingDB} );  
    my $mesg = $coder->decode( $message );
    $os->write( prepare_hourly( $os, $mesg ), prepare_daily( $os, $mesg ), prepare_monthly( $os, $mesg ) );
  }
});

sub prepare_cycle {
  my $os   = shift;
  my $cycle_name = shift;
  my $cycle_val  = shift;
  my $mesg = shift;
  my $objects = $os->search( $cycle_name, { host => $mesg->{host}, cycle => $cycle_val });
  my $object;
  if (!@$objects) {
    $object = { type => $cycle_name, cycle => $cycle_val, host => $mesg->{host}, id => $mesg->{host} . $cycle_val };
  } else {
    $object = $objects->[0];
  }
  $object->{ $mesg->{type} } += $mesg->{count};
  $object->{uris}->{ $mesg->{request} }->{ $mesg->{type} } += $mesg->{count};
  if ( $mesg->{type} eq 'bandwidth' ) {
    $object->{uris}->{ $mesg->{request} }->{hitcount} += 1;
  }
  return [$cycle_name, $object, 0];
}

sub prepare_monthly {
  my $os = shift;
  my $mesg = shift;
  my $time = DateTime->now;
  my $cycle = sprintf("%s%02d", $time->year, $time->month);
  return prepare_cycle( $os, "billing_monthly", $cycle, $mesg );
}

sub prepare_daily {
  my $os = shift;
  my $mesg = shift;
  my $time = DateTime->now;
  my $cycle = sprintf("%s%02d%02d", $time->year, $time->month, $time->day);
  return prepare_cycle( $os, "billing_daily", $cycle, $mesg );
}

sub prepare_hourly {
  my $os = shift;
  my $mesg = shift;
  my $time = DateTime->now;
  my $cycle = sprintf("%s%02d%02d%02d", $time->year, $time->month, $time->day, $time->hour);
  return prepare_cycle( $os, "billing_hourly", $cycle, $mesg );
}

1;
