#!/usr/bin/env perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use Scalar::Util qw(reftype);
use File::Temp qw(tempfile);

use mocked [qw(JavaScript t/Mock)];
use mocked [qw(HostConfig t/Mock)];
use_ok('RSP::JS::Engine::SpiderMonkey');

my $coderef = sub { "boo" };
my ($fh, $filename) = tempfile();
my $host = HostConfig->new({
    interrupt_handler => $coderef,
    extensions => [qw(RSP::Extension::Example)],
    bootstrap_file => $filename,
    hostname => 'flibble',
});

create_instance: {
    my $je = RSP::JS::Engine::SpiderMonkey->new();
    $je->initialize;
    my $ji = $je->create_instance({ config => $host });

    isa_ok($ji, 'RSP::JS::Engine::SpiderMonkey::Instance');

    ok($ji->runtime, q{Instance has a runtime});
    isa_ok($ji->runtime, 'JavaScript::Runtime');

    is($JavaScript::Runtime::ALLOC_SIZE, $host->alloc_size, q{Runtime is created with correct size});
}

interrupt_handler: {
    my $je = RSP::JS::Engine::SpiderMonkey->new;
    my $ji = $je->create_instance({ config => $host });

    is($ji->interrupt_handler, $coderef, q{Interrupt handler stores coderef});
    is($JavaScript::Runtime::INTERRUPT_HANDLER, $coderef, q{Interrupt handler set in runtime});
}

context: {
    my $je = RSP::JS::Engine::SpiderMonkey->new;
    my $ji = $je->create_instance({ config => $host });
    my $context = $ji->context;
    isa_ok($context, 'JavaScript::Context');

    is($ji->strict_enabled, 1, q{Instance is strict});
    is($ji->e4x_enabled, 1, q{Instance has e4x});
    is($ji->version, '1.8', q{Version is correct});

    #$ji->options;
    is_deeply($JavaScript::Context::OPTIONS, [qw(e4x strict)], q{Options set in context});
}

extensions: {
    {
        package RSP::Extension::Example;
           sub providing_class { shift }
           sub should_provide { 1 }
           sub provides {
                { example => { hello => sub { "world" } } }
           }
        1;
    }    
    my $je = RSP::JS::Engine::SpiderMonkey->new;
    my $ji = $je->create_instance({ config => $host });

    is_deeply($ji->extensions, [qw(RSP::Extension::Example)], q{List of extensions is correct});
    ok(reftype($JavaScript::Context::BINDED->{'system'}{example}{hello}) eq 'CODE', q{Extension binded});
}

initialize: {

    my $je = RSP::JS::Engine::SpiderMonkey->new;
    my $ji = $je->create_instance({ config => $host });
    $ji->initialize;
    is($JavaScript::Context::FILE, $filename, q{Bootstrap file evaluated});
    
    # should this be handled by the Host object?
    $host->bootstrap_file('reallyreallyreallyshouldnotbehere');
    $ji = $je->create_instance({ config => $host });
    throws_ok {
        $ji->initialize
    } qr{bootstrap file 'reallyreallyreallyshouldnotbehere' does not exist for host 'flibble': },
        q{Non-existing bootstrap file throws exception};

    $host->bootstrap_file($filename);
    $ji = $je->create_instance({ config => $host });
    local $JavaScript::Context::EVAL_RESULT = 0;
    throws_ok {
        $ji->initialize
    } qr{^Could not evaluate bootstrap file '[^']+?': \[mocked\] fail},
        q{bootstrap file failure throws exception};

}

run: {
    my $je = RSP::JS::Engine::SpiderMonkey->new;
    my $ji = $je->create_instance({ config => $host });
    $ji->initialize;
    
    $ji->run;
    is($JavaScript::Context::CALLED, 'main', q{Entrypoint called});
    is_deeply($JavaScript::Context::CALLED_ARGS, [], q{Entrypoint arguments correct});

    local $JavaScript::Context::CALL_FAIL = 1;
    $ji = $je->create_instance({ config => $host });
    $ji->initialize;

    throws_ok {
        $ji->run
    } qr{Could not call function 'main': \[mocked\] call fail},
        q{Entrypoint function failure throws exception};
}

run_with_args: {
    my $je = RSP::JS::Engine::SpiderMonkey->new;
    my $ji = $je->create_instance({ config => $host });
    $ji->initialize;
    
    $ji->run([qw(hehe hoho haha)]);
    is($JavaScript::Context::CALLED, 'main', q{Entrypoint called});
    is_deeply($JavaScript::Context::CALLED_ARGS, [qw(hehe hoho haha)], q{Entrypoint arguments correct (from run)});

    $ji->run(bob => [qw(a b c)]);
    is($JavaScript::Context::CALLED, 'bob', q{Entrypoint called (from run)});
    is_deeply($JavaScript::Context::CALLED_ARGS, [qw(a b c)], q{Entrypoint arguments correct (from run)});
}

cleanup: {
    my $je = RSP::JS::Engine::SpiderMonkey->new;
    {
        my ($fh, $filename) = tempfile();
        my $ji = $je->create_instance({ config => $host });
        $ji->initialize;
    
        $ji->run;
    }
    is($JavaScript::Context::UNBINDED, 'system', q{Value unbinded during destruction});

    our $CLEANED_UP_CONTEXT = 0;
    our $CLEANED_UP_RUNTIME  = 0;
    {
        local $CLEANED_UP_CONTEXT;
        $je = RSP::JS::Engine::SpiderMonkey->new;
        {
            my ($fh, $filename) = tempfile();
            my $ji = $je->create_instance({ config => $host });
            $ji->initialize;
        
            $ji->run;
            $ji->clear_context;
            $JavaScript::Context::ON_DESTROY = sub { $CLEANED_UP_CONTEXT = 1 };
        }
        ok($CLEANED_UP_CONTEXT, q{Ensure context was cleaned up});
    }
  
    {
        local $CLEANED_UP_RUNTIME;
        $je = RSP::JS::Engine::SpiderMonkey->new;
        {
            my ($fh, $filename) = tempfile();
            my $ji = $je->create_instance({ config => $host });
            $ji->initialize;
        
            $ji->run;
            $ji->clear_runtime;
            $JavaScript::Runtime::ON_DESTROY = sub { $CLEANED_UP_RUNTIME = 1 };
        }
        ok($CLEANED_UP_RUNTIME, q{Ensure context was cleaned up});
    }

    {

        local $CLEANED_UP_CONTEXT;
        local $CLEANED_UP_RUNTIME;
        $je = RSP::JS::Engine::SpiderMonkey->new;
        {
            my ($fh, $filename) = tempfile();
            my $ji = $je->create_instance({ config => $host });
            $ji->initialize;
        
            $ji->run;
            $ji->clear_context;
            $ji->clear_runtime;
            $JavaScript::Context::ON_DESTROY = sub { $CLEANED_UP_CONTEXT = 1 };
            $JavaScript::Runtime::ON_DESTROY = sub { $CLEANED_UP_RUNTIME = 1 };
        }
        ok($CLEANED_UP_RUNTIME && $CLEANED_UP_CONTEXT, q{Both context and runtime are cleared});
    }

}
