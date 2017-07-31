package TestFor::Code::TidyAll::Parallel;

use Test::Class::Most parent => 'TestHelper::Test::Class';
use strict;
use warnings;

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
