#!/usr/bin/perl

use strict;
use warnings;

use lib::relative 'lib';

use Config     qw( %Config );
use File::Spec ();

# We need to make sure that t/lib is seen across forks _and_ we want to make
# sure that the paths are absolute because Code::TidyAll may chdir while
# running.
$ENV{PERL5LIB} = join(
    $Config{path_sep},
    File::Spec->rel2abs('./t/lib'),
    split(
        $Config{path_sep},
        ( $ENV{PERL5LIB} || q{} )
    )
);

use TestFor::Code::TidyAll::Basic ();
TestFor::Code::TidyAll::Basic->runtests;
