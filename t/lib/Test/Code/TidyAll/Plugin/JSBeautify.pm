package Test::Code::TidyAll::Plugin::JSBeautify;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub _extra_path {
    'node_modules/.bin';
}

sub test_main : Tests {
    my $self = shift;

    $self->require_executable('node');

    my $source = 'sp.toggleResult=function(id){foo(id)}';
    $self->tidyall(
        source      => $source,
        expect_tidy => 'sp.toggleResult = function(id) {\n    foo(id)\n}',
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '--indent-size 3 --brace-style expand' },
        expect_tidy => 'sp.toggleResult = function(id)\n{\n   foo(id)\n}',
    );
}

1;
