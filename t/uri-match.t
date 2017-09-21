#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Test::More tests => 7;
use Soup::URI 'uri_match';

my $url0 = 'http://www.Exmple.com/path/to';
my $url1 = 'http://exmple.com/path/to/file.html?par1=val1&par2=val2#my-anchor';
my $url2 = 'https://test.org/path/to/my-file';
my $url3 = 'http://www.exmple.com/path2/to/';
my $url4 = 'bla-bla-bla';
my $url5 = 'http://История.рф/Путин-Владимир-Владимирович';
my $url6 = 'http://www.история.рф/Путин-Владимир-Владимирович/биография';
my $url7 = 'http://www.antech.ru/help/dictionary/%D0%93/%D0%B3%D0%BE%D1%84%D1%80%D0%BE%D1%82%D0%B0%D1%80%D0%B0/';
my $url8 = 'http://aNtEcH.Ru/help/dictionary/%D0%93/%D0%B3%D0%BE%D1%84%D1%80%D0%BE%D1%82%D0%B0%D1%80%D0%B0/show-must-go-on';

ok(uri_match($url0, $url1, 1) == 1);
ok(uri_match($url0, $url1)    == 0);
ok(uri_match($url0, $url2, 1) == 0);
ok(uri_match($url0, $url3, 0) == 0);
ok(!defined uri_match($url0, $url4, 1));
ok(uri_match($url5, $url6, 1) == 1);
ok(uri_match($url7, $url8, 1) == 1);

__END__

