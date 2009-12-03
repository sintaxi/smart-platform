package JavaScript;

package JavaScript::Runtime;

use unmocked 'Moose';
use unmocked 'Scalar::Util', 'reftype';

our $INTERRUPT_HANDLER;
sub set_interrupt_handler {
    my ($self, $coderef) = @_;
    $INTERRUPT_HANDLER = $coderef;
}

sub create_context {
    return JavaScript::Context->new;
}

our $ON_DESTROY;
sub DEMOLISH {
    if($ON_DESTROY && reftype($ON_DESTROY) eq 'CODE'){
        $ON_DESTROY->();
        undef($ON_DESTROY);
    }
}

package JavaScript::Context;

use unmocked 'Moose';
use unmocked 'Scalar::Util', 'reftype';

our $JS_VERSION;
sub set_version {
    my ($self, $version) = @_;
    $JS_VERSION = $version;
}

sub get_version {
    $JS_VERSION;
}

our $OPTIONS;
sub toggle_options {
    my ($self, @opts) = @_;
    $OPTIONS = [@opts];
}

our $BINDED;
sub bind_value {
    my ($self, %opts) = @_;
    $BINDED = { %opts };
}

our $FILE;
our $EVAL_RESULT = 1;
sub eval_file {
    my ($self, $file) = @_;
    $FILE = $file;
    if(!$EVAL_RESULT){
        die "[mocked] fail";
    }
    return $EVAL_RESULT;
}

our $CALLED;
our $CALLED_ARGS;
our $CALL_FAIL = 0;
sub call {
    my ($self, $entry, @args) = @_;
    $CALLED = $entry;
    $CALLED_ARGS = [@args];
    if($CALL_FAIL){
        die "[mocked] call fail";
    }
}

our $UNBINDED;
sub unbind_value {
    my ($self, $value) = @_;
    $UNBINDED = $value;
}

our $ON_DESTROY;
sub DEMOLISH {
    if($ON_DESTROY && reftype($ON_DESTROY) eq 'CODE'){
        $ON_DESTROY->();
        undef($ON_DESTROY);
    }
}

1;
