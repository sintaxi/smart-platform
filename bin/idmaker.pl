#!/usr/bin/perl

use strict;
use Digest::MD5 'md5_hex';

print md5_hex( $ARGV[0], $ARGV[1] ), "\n";
