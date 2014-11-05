package Test::Code::TidyAll::Plugin::JSBeautify;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $source = 'sp.toggleResult=function(id){foo(id)}';
    $self->tidyall(
        source      => $source,
        expect_tidy => 'sp.toggleResult = function(id) {\n    foo(id)\n}\n',
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '--indent-size 3 --brace-style expand' },
        expect_tidy => 'sp.toggleResult = function(id)\n{\n   foo(id)\n}\n',
    );
}

1;
