package RSP::JS::Engine::SpiderMonkey;

use Moose;
use Moose::Util;

use RSP::JS::Engine::SpiderMonkey::Instance;
use RSP::Config;
use RSP::Config::Host;

sub create_instance {
    my $self = shift;
    return RSP::JS::Engine::SpiderMonkey::Instance->new(@_);
}

sub initialize {
    my ($self) = @_;
    Moose::Util::apply_all_roles( RSP::Config->meta, 'RSP::Role::Config::SpiderMonkey' );
    #Moose::Util::apply_all_roles( RSP::Config::Host->meta, 'RSP::Role::Config::SpiderMonkey::Host' );
}

sub applicable_host_config_roles {
    qw(RSP::Role::Config::SpiderMonkey::Host);
}

1;
