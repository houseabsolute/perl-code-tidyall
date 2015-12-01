package Test::Code::TidyAll::DiffOnTidyError;

use Test::Class::Most parent => 'Code::TidyAll::Test::Class';
use strict;
use warnings;

sub test_diff_on_tidy_error : Tests {
    my $self = shift;

    $self->tidy(
        plugins => {
            '+Code::TidyAll::Test::Plugin::UpperText' => {
                diff_on_tidy_error => 1,
                select             => '**/*.txt',
            },
        },
        source  => { "foo.txt"  => "abc" },
        options => { check_only => 1 },
        desc    => 'diff on tidy error',
        errors  => qr/needs tidying/,
        like_output => qr/UpperText made the following change:\n.+abc\n.+ABC/s,
    );
}

1;
