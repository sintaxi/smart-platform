package RSP::Role::Extension::JSInstanceManipulation;

use Moose::Role;
use Try::Tiny;

has js_instance => (is => 'ro', required => 1);

sub bind_extension {
    my ($self, $items) = @_;

    my $pkg = blessed($self);
    $pkg =~ s/::/__/g;
    $pkg = lc($pkg);

    $self->js_instance->bind_value("extensions.$pkg", $items);
}

# this method creates a closure around methods on the extension that are called as Javascript
# functions
# XXX - should I rename this to 'generate_js_function_closure' ???
sub generate_js_closure {
    my ($self, $method) = @_;
    my $pkg = blessed($self);

    return sub {
        my @args = @_;
        my @return;
        my $error;
        local $SIG{__DIE__};
        try {
            @return = ( $self->$method(@args) );
        } catch {
            $error = $_;
            $error =~ s/\n/\\n/g;
            $error =~ s/'/\\'/g;
            $self->js_instance->eval(
                qq{throw '$pkg threw a binding error: $error';}
            );
            $error = $@;
            die $error;
        };

        return $return[0];
    };
}

# this method creates a closure around methods that are usable with specially bound Javascript
# objects that are actually instances of Perl classes
sub generate_js_method_closure {
    my ($self, $closure) = @_;
    my $pkg = blessed($self);

    return sub {
        local $SIG{__DIE__};
        my ($obj, @args) = @_;
        my @return;
        my $error;
        try {
            @return = ( $obj->$closure(@args) );
        } catch {
            $error = $_;
            $error =~ s/\n/\\n/g;
            $error =~ s/'/\\'/g;
            $self->js_instance->eval(
                qq{throw '$pkg threw a binding error: $error';}
            );
            $error = $@;
            $error =~ s/\n//g;
            die "$error\n";
        };

        return $return[0];
    };
}

1;
