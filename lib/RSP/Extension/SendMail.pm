package RSP::Extension::SendMail;

use Moose;

with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use Email::Send;
use Email::Simple;
use Email::Simple::Creator;

sub bind {
    my ($self) = @_;
    $self->bind_extension({
        email => {
            'send' => $self->generate_js_closure('email_send'),
        },
    });
}

sub email_send {
    my ($self, $headers, $body) = @_;
    if (!$headers->{To}) {
      die "no 'To' header\n";
    } elsif ( !$headers->{From} ) {
      die "no 'From' header\n";
    } elsif( !$headers->{Subject} ) {
      die "no 'Subject' header\n";
    }

    if (!$body) {
      die "no body\n";
    }

    my $message = Email::Simple->create;
    foreach my $key (keys %$headers) {
      $message->header_set($key, $headers->{$key});
    }

    $message->body_set( $body );
    my $sender = Email::Send->new;
    $sender->mailer_args([Host=>'localhost']);
    my $result = $sender->send( $message );
    select(undef, undef, undef, 0.25);
    return 1;
}

1;
