#!/usr/bin/perl

use 5.014002;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Soup::URI',
    VERSION_FROM      => 'lib/Soup/URI.pm', # finds $VERSION
    PREREQ_PM         => {
      'Test::LeakTrace' => 0.14, # Only for test
      'Test::Deep' => 0.11, # Only for test
    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/Soup/URI.pm',
       AUTHOR         => 'Zykov Mikhail <zmsmihail@yandex.ru>') : ()),
    LIBS              => ['-lpthread -lsoup-2.4 -lgio-2.0 -lgobject-2.0 -lglib-2.0'],
    DEFINE            => '',
    INC               => '-I ./include '.
                         '-I/usr/include/libsoup-2.4 '.
                         '-I/usr/include/libxml2 '.
                         '-I/usr/include/glib-2.0 '.
                         '-I/usr/lib/x86_64-linux-gnu/glib-2.0/include',
);

