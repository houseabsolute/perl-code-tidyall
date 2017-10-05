#!/usr/bin/perl

use strict;
use warnings;

use lib::relative 'lib';

use Config;
use File::Spec ();

$ENV{PERL5LIB} = join $Config{path_sep},
    File::Spec->rel2abs('./t/lib'), split $Config{path_sep},
    ( $ENV{PERL5LIB} || q{} );

use TestFor::Code::TidyAll::Basic;
TestFor::Code::TidyAll::Basic->runtests;
