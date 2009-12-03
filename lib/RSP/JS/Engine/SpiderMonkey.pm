package RSP::JS::Engine::SpiderMonkey;

use Moose;
use RSP::JS::Engine::SpiderMonkey::Instance;

sub create_instance {
    my $self = shift;
    return RSP::JS::Engine::SpiderMonkey::Instance->new(@_);
}

1;
