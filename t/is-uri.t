#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Test::More tests => 2;
use Soup::URI 'is_uri';

my $url1 = 'http://www.exmple.com/path/to/file.html?par1=val1&par2=val2#my-anchor';
my $url2 = 'bla-bla-bla';

ok(is_uri($url1) == 1);
ok(is_uri($url2) == 0);

__END__

