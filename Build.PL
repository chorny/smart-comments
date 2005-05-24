use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Smart::Comments',
    license             => 'perl',
    dist_author         => 'Damian Conway <DCONWAY@cpan.org>',
    dist_version_from   => 'lib/Smart/Comments.pm',
    requires => {
        'Test::More'     => 0,
        'version'        => 0,
        'Text::Balanced' => 0,
        'Data::Dumper'   => 0,
        'Filter::Simple' => 0,
        'List::Util'     => 0,
    },
    add_to_cleanup      => [ 'Smart-Comments-*' ],
);

$builder->create_build_script();
