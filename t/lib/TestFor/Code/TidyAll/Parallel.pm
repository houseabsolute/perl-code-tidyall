package TestFor::Code::TidyAll::Parallel;

use Test::Class::Most parent => 'TestHelper::Test::Class';
use strict;
use warnings;

use Module::Runtime qw( require_module );
use Try::Tiny       qw( try );

BEGIN {
    for my $mod (qw( Parallel::ForkManager )) {
        unless ( try { require_module($mod); 1 } ) {
            __PACKAGE__->SKIP_CLASS("This test requires the $mod module");
            return;
        }
    }
}

sub test_parallel : Tests {
    my $self = shift;

    if ( $^O eq 'MSWin32' ) {
        $self->builder->skip('Parallel::ForkManager does not seem to work on Windows');
        return;
    }

    $self->tidy(
        plugins => {
            '+TestHelper::Plugin::UpperText' => {
                select => '**/*.txt',
            },
        },
        source => {
            'foo.txt'  => "abc\n",
            'bar.txt'  => "def\n",
            'baz.txt'  => "ghi\n",
            'quux.txt' => "jkl\n",
        },
        dest => {
            'foo.txt'  => "ABC\n",
            'bar.txt'  => "DEF\n",
            'baz.txt'  => "GHI\n",
            'quux.txt' => "JKL\n",
        },
        options     => { jobs => 3 },
        desc        => 'three jobs in parallel',
        like_output => qr/\Q[tidied]\E +bar\.txt/s,
    );
}

1;
