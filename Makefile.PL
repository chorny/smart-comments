use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Smart::Comments',
    AUTHOR              => 'Damian Conway <DCONWAY@cpan.org>',
    VERSION_FROM        => 'lib/Smart/Comments.pm',
    ABSTRACT_FROM       => 'lib/Smart/Comments.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
        'Text::Balanced' => 2.0,
        'Data::Dumper'   => 0,
        'Filter::Simple' => 0.80,
        'List::Util'     => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Smart-Comments-*' },
);
