package Code::TidyAll::t::Plugin::MasonTidy;
use Test::Class::Most parent => 'Code::TidyAll::t::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $source;

    $source = '%if($foo) {\n%bar(1,2);\n%}';
    $self->tidyall(
        source      => $source,
        expect_tidy => '% if ($foo) {\n%   bar( 1, 2 );\n% }'
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '--perltidy-argv="-pt=2 -i=3"' },
        expect_tidy => '% if ($foo) {\n%    bar(1, 2);\n% }'
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '--perltidy-line-argv=" "' },
        expect_tidy => '% if ($foo) {\n%     bar( 1, 2 );\n% }'
    );
    $self->tidyall(
        source       => $source,
        conf         => { argv => '--badoption' },
        expect_error => qr/Unknown option: badoption/
    );
}

1;
