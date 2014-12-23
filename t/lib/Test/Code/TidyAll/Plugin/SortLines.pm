package Test::Code::TidyAll::Plugin::SortLines;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    $self->tidyall( source => "c\nb\na\n",   expect_tidy => "a\nb\nc\n" );
    $self->tidyall( source => "\n\na\n\n\n", expect_tidy => "a\n" );
}

1;
