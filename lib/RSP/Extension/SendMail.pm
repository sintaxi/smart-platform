package RSP::Extension::SendMail;

use strict;
use warnings;
use Email::Send;
use Email::Simple;
use Email::Simple::Creator;

sub provide {
  my $class = shift;
  my $tx = shift;
  return (
    'email' => {
      'send' => sub {
        my $headers = shift;
        my $body    = shift;
        if (!$headers->{To}) {
          die "no 'To' header";
        } elsif ( !$headers->{From} ) {
          die "no 'From' header";
        } elsif( !$headers->{Subject} ) {
          die "no 'Subject' header";
        }
        if (!$body) {
          die "no body";
        }
        
        my $message = Email::Simple->create;
        foreach my $key (keys %$headers) {
          $message->header_set($key, $headers->{$key});
        }
        $message->body_set( $body );
        $tx->log($message->as_string);
        my $sender = Email::Send->new;
        $sender->mailer_args([Host=>'localhost']);
        my $result = $sender->send( $message );
        $tx->log("sent with status code $result");
        select(undef, undef, undef, 0.25);
        return 1;
       }
    }
  );
}

1;
