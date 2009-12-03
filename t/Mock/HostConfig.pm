package HostConfig;

use Moose;

has interrupt_handler   => (is => 'rw', isa => 'Maybe[CodeRef]');
has extensions          => (is   => 'rw', isa => 'ArrayRef', default => sub { [] }); 
has bootstrap_file      => (is => 'rw', isa => 'Str');
has hostname            => (is => 'rw', isa => 'Str');
has entrypoint          => (is => 'rw', isa => 'Str', default => 'main');
has arguments           => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has use_e4x             => (is => 'rw', isa => 'Bool', default => 1);
has use_strict          => (is => 'rw', isa => 'Bool', default => 1);

1;
