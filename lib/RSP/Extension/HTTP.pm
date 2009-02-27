package RSP::Extension::HTTP;

use strict;
use warnings;

use HTTP::Request;
use LWPx::ParanoidAgent;

use base 'RSP::Extension';

our $VERSION = '1.00';

sub exception_name {
  return "system.http";
}

## why does LWPx::ParanoidAgent need this?
sub LWP::Debug::debug { }
sub LWP::Debug::trace { }

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $ua = LWPx::ParanoidAgent->new;
  $ua->agent("Reasonably Smart Platform / HTTP / $VERSION");
  $ua->timeout( 10 );  
  return {
    'http' => {
      'request' => sub {
        my $response = eval {
          my $req = shift;
          my $r;
          if ( ref( $req ) ) {
            $r = HTTP::Request->new( @$req );
          } else {
            $r = HTTP::Request->new( $req, @_ );
          }
          $ua->request( $r );
        };
        if ($@) {
          RSP::Error->throw("error: $@");
        }
        return $class->response_to_object( $response );
      }
    }
  };
}

sub response_to_object {
  my $class = shift;
  my $response = shift;
  my %headers = %{ $response->{_headers} };
  return {
    'headers'=> \%headers,
    'content' => $response->decoded_content
  }
}

1;
