#!/usr/bin/perl

use strict;
use warnings;

use RSP;
use Spread;
use JSON::XS;
use RSP::ObjectStore;
use RSP::Queue::Client;

my $FLUSH_AT = 10;

my $coder = JSON::XS->new->allow_nonref;
$0 = "RSP Billing Collation";

my $hosts = {};

RSP::Queue::Client->listen( "billing", sub {
  my ($mbox, $private_group, $service_type, $sender, $groups, $mess_type, $endian, $message) = @_;
  if ( $service_type & Spread::MEMBERSHIP_MESS ) {
    my $members = scalar(@$groups);
    print "There are now $members member(s) of the $sender group\n";
  } else {
    my $data = $coder->decode( $message );
    my $hosth = $hosts->{$data->{host}} ||= { id => $data->{host} };
    $hosth->{ logged_entries }+=1;
    $hosth->{ $data->{type} }->{ total } += $data->{count};
    $hosth->{ $data->{type} }->{ $data->{request} } += $data->{count};

    if ($hosth->{logged_entries} == $FLUSH_AT) {
      delete $hosth->{logged_entries};
      eval {
        flush_data_to_db( $hosth );
        delete $hosts->{$data->{host}};
      };
      if ($@) { warn("could not flush: $@"); }
    }

  }
});

sub flush_data_to_db {
  my $host = shift;
  my $id   = $host->{id};
  my $os = RSP::ObjectStore->new( RSP->config->{server}->{BillingDB} );
  
  ## first of all, get the old object out...
  my $oldparts = $os->get($id);
  my $oldobj   = {};

  foreach my $piece (@$oldparts) {
    my ($key, $val) = @$piece;
    $oldobj->{$key} = $coder->decode( $val );
  }

  update_stats_from( $host, $oldobj );
  
  ## now write the new one...
  my @parts = ();
  foreach my $key (keys %$oldobj) {
    push @parts, [ $id, $key, $coder->encode( $oldobj->{$key} ) ];
  }
  push @parts, [ $id, "type", $coder->encode( "host billing" ) ];
  $os->save( @parts );
}

sub update_stats_from {
  my $from = shift;
  my $to   = shift;
  
  foreach my $tl (keys %$from) {
    ## these are the count types, opcount, storage, etc...
    my $counter = $from->{$tl};
    if ( ref( $counter ) ) {
      foreach my $logged ( keys %$counter ) {
        ## this is the data we need to collate
        $to->{$tl}->{$logged} += $counter->{$logged};
      }
    }
  }  
}

1;
