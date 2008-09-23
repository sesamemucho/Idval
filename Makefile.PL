use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Idval',
    AUTHOR              => 'Bob Forgey <rforgey@grumpydogconsulting.com>',
    VERSION_FROM        => 'lib/Idval.pm',
    ABSTRACT_FROM       => 'lib/Idval.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Idval-*' },
);
