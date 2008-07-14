#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;

use_ok("RSP");
ok( my $cfg = RSP->config() );
isa_ok( $cfg, "Config::Tiny" );
print $cfg->{_}->{extension};