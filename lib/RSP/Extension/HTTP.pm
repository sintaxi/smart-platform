package RSP::Extension::HTTP;

use strict;
use warnings;

use Encode;
use HTTP::Request;
use LWPx::ParanoidAgent;

use base 'RSP::Extension';

our $VERSION = '1.00';

sub exception_name {
  return "system.http";
}

## why does LWPx::ParanoidAgent need this?
{
    no warnings 'redefine';
    sub LWP::Debug::debug { }
    sub LWP::Debug::trace { }
}

sub provides {
  my $class = shift;
  my $tx    = shift;
  my $ua = LWPx::ParanoidAgent->new;
  $ua->agent("Joyent Smart Platform / HTTP / $VERSION");
  $ua->timeout( 10 );
  return {
    'http' => {
      'request' => sub {
        my $response = eval {
	  my @args;
	  foreach my $part (@_) {
	    if (!ref($part)) {
	      push( @args, Encode::encode("utf8", $part ) );
	    } else {
	      push( @args, $part );
	    }
	  }
          my $req = shift @args;
          my $r;
          if ( ref( $req ) ) {
            $r = HTTP::Request->new( @$req );
          } else {
            $r = HTTP::Request->new( $req, @args );
          }
          $ua->request( $r );
        };
        if ($@) {
          RSP::Error->throw("error: $@");
        }
        my $ro = $class->response_to_object( $response );
	return $ro;
      }
    }
  };
}

sub response_to_object {
  my $class = shift;
  my $response = shift;
  my %headers = %{ $response->{_headers} };
  my $ro = {
	    'headers' => \%headers,
	    'content' => $response->decoded_content,
	    'code'    => $response->code,
	   };
  return $ro;
}

1;
