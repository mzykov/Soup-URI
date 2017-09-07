package Soup::URI;

use 5.014002;
use strict;
use warnings;
use utf8;

our $VERSION = '1.0';

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ('all' => [qw(is_uri is_web_uri uri_match)]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

require XSLoader;
XSLoader::load('Soup::URI', $VERSION);

1;

__END__

=head1 NAME

Soup::URI - fast processing URI's

=head1 SYNOPSIS

Fast common routines for processing URI's.
Module has written using XS.

=head1 DESCRIPTION

  use Soup::URI qw(is_web_uri uri_match);
  
=head1 EXPORT

None by default.

=head1 AUTHOR

Zykov Mikhail, E<lt>zmsmihail@yandex.ruE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Zykov Mikhail

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

