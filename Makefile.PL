#!perl -w
use strict;
use ExtUtils::MakeMaker;

my @programs_to_install = qw(sitetear);

WriteMakefile(
    'NAME'	 => 'HTML::SiteTear',
    'VERSION_FROM' => 'lib/HTML/SiteTear.pm',
	'EXE_FILES'     => [ map {"bin/$_"} @programs_to_install ],
	'PREREQ_PM' => {
        'HTML::Parser' => 0
    },
);
