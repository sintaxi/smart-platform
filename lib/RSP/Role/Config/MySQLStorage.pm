package RSP::Role::Config::MySQLStorage;

use Moose::Role;
use RSP::Config::MySQL;

has mysql => (is => 'ro', isa => 'Maybe[RSP::Config::MySQL]', lazy_build => 1);
sub _build_mysql {
    my ($self) = @_;
    if(my $conf = $self->_config->{mysql}){
        return RSP::Config::MySQL->new($conf);
    }
    return;
}

1;
