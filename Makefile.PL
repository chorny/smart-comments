#!/usr/bin/env perl

use inc::Module::Install;

name		('Smart-Comments');
author		('Damian Conway <damian@conway.org>');
abstract	('Comments that come to life');
license		('perl');
version_from	('lib/Smart/Comments.pm');

requires        (qw(
    perl            5.006
    List::Util      0
    Filter::Simple  0
));
build_requires  ('Test::More');
auto_include_deps();

WriteAll( sign => 1 );
