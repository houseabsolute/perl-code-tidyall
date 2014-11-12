package Test::Code::TidyAll::Plugin::CSSUnminifier;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub _extra_path {
    'node_modules/.bin';
}

sub test_main : Tests {
    my $self = shift;

    $self->require_executable('node');

    my $source = 'body {\nfont-family:helvetica;\nfont-size:15pt;\n}';
    $self->tidyall(
        source      => $source,
        expect_tidy => 'body {\n    font-family: helvetica;\n    font-size: 15pt;\n}\n'
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '-w=2' },
        expect_tidy => 'body {\n  font-family: helvetica;\n  font-size: 15pt;\n}\n'
    );
}

1;
