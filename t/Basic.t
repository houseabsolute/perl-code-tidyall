#!/usr/bin/perl

use strict;
use warnings;

use Config;
use File::Spec ();
use FindBin    ();

use lib "$FindBin::Bin/lib";

$ENV{PERL5LIB} = join $Config{path_sep},
    File::Spec->rel2abs('./t/lib'), split $Config{path_sep},
    ( $ENV{PERL5LIB} || q{} );

use TestFor::Code::TidyAll::Basic;
TestFor::Code::TidyAll::Basic->runtests;
