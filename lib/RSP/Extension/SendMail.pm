package RSP::Extension::SendMail;

use strict;
use warnings;
use Email::Send;
use Email::Simple;
use Email::Simple::Creator;

use base 'RSP::Extension';

sub exception_name {
  return "system.email";
}

sub provides {
  my $class = shift;
  my $tx = shift;
  return {
    'email' => {
      'send' => sub {
        my $headers = shift;
        my $body    = shift;
        if (!$headers->{To}) {
          RSF::Error->throw("no 'To' header");
        } elsif ( !$headers->{From} ) {
          RSF::Error->throw("no 'From' header");
        } elsif( !$headers->{Subject} ) {
          RSF::Error->throw("no 'Subject' header");
        }

        if (!$body) {
          RSF::Error->throw("no body");
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
  };
}

1;
