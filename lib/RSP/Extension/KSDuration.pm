package RSP::Extension::KSDuration;

use strict;
use warnings;
use DateTime;
use DateTime::Duration;
use DateTime::Event::Recurrence;

sub provide {

  return (
    
    ks => {
    
      'recurrence' => \&calculate_recurrence
    
    }
  
  );

}

sub calculate_recurrence {
  my $args   = shift;
  my $start  = DateTime->from_epoch( epoch => $args->{start} / 1000 );
  my $end    = DateTime->from_epoch( epoch => $args->{end} / 1000 );
  my $period = $args->{period};

  my $recurrence;
  my $duration_args = {};
  if ( $period =~ /Session/i ) {
    $recurrence = "weekly";
    $duration_args = $args->{duration};
  } elsif ( $period =~ /Week/i ) {
    $recurrence = "weekly";
    $duration_args = $args->{duration};    
  } elsif ( $period =~ /days/i ) {
    $recurrence = 'daily';
  } elsif ( $period =~ /month/i ) {
    $recurrence = 'monthly';
  } else {
    $recurrence = $period;
  }
  
  my $set = eval {
    DateTime::Event::Recurrence->$recurrence( %$duration_args );
  };
  if ($@) {
    print "RECURRENCE_ERROR: $@";
    die $@;
  }
 
  my @days = map { 
    $_->epoch * 1000
  } $set->as_list( start => $start, end => $end );

  return \@days;
}


1;

