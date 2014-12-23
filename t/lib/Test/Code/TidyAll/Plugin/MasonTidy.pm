package Test::Code::TidyAll::Plugin::MasonTidy;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $source;

    $source = '%if($foo) {\n%bar(1,2);\n%}';
    $self->tidyall(
        source      => $source,
        conf        => { argv => '-m 1' },
        expect_tidy => '% if ($foo) {\n%     bar( 1, 2 );\n% }'
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '-m 1 --perltidy-argv="-pt=2 -i=3"' },
        expect_tidy => '% if ($foo) {\n%    bar(1, 2);\n% }'
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '-m 2 --perltidy-line-argv=" "' },
        expect_tidy => '% if ($foo) {\n%     bar( 1, 2 );\n% }'
    );
    $self->tidyall(
        source       => $source,
        conf         => { argv => '-m 1 --badoption' },
        expect_error => qr/Usage/
    );
}

1;
