package Foo;

use strict;
use warnings;

use Moo;
extends 'Code::TidyAll::Plugin';

use Test::More;

sub transform_source {
    for my $dir (qw( t/inc1 t/inc2 )) {
        ok(
            ( grep {m{$dir}} @INC ),
            "\@INC still inclues $dir when plugin is run"
        );
    }

    return $_[1];
}

1;
