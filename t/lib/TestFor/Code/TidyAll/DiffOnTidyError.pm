package TestFor::Code::TidyAll::DiffOnTidyError;

use Test::Class::Most parent => 'TestHelper::Test::Class';
use strict;
use warnings;

sub test_diff_on_tidy_error : Tests {
    my $self = shift;

    $self->tidy(
        plugins => {
            '+TestHelper::Plugin::UpperText' => {
                diff_on_tidy_error => 1,
                select             => '**/*.txt',
            },
        },
        source      => { 'foo.txt'  => 'abc' },
        options     => { check_only => 1 },
        desc        => 'diff on tidy error',
        errors      => qr/needs tidying/,
        like_output => qr/UpperText made the following change:\n.+abc\n.+ABC/s,
    );

    $ENV{GITHUB_ACTIONS} = 'true';
    $self->tidy(
        plugins => {
            '+TestHelper::Plugin::UpperText' => {
                diff_on_tidy_error => 1,
                select             => '**/*.txt',
            },
        },
        source  => { 'foo.txt'  => 'abc' },
        options => { check_only => 1 },
        desc    => 'diff on tidy error running in github actions',
        errors  => qr/::error file=foo\.txt::File foo\.txt needs tidying/,
    );
}

1;
