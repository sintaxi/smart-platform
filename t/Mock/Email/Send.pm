package Email::Send;

use unmocked "Moose";

has mailer_args => (is => 'rw', isa => 'ArrayRef');

our $LAST_SENT;
sub send {
    my ($self, $message) = @_;
    $LAST_SENT = {
        host => $self->mailer_args->[1],
        from => $message->header('From'),
        to => $message->header('To'),
        subject => $message->header('Subject'),
        body => $message->body,
    };
    return;
}

1;
