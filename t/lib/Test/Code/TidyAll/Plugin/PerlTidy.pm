package Test::Code::TidyAll::Plugin::PerlTidy;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $source = 'if (  $foo) {\nmy   $bar =  $baz;\n}\n';
    $self->tidyall(
        conf        => { argv => '-npro' },
        source      => $source,
        expect_tidy => 'if ($foo) {\n    my $bar = $baz;\n}\n'
    );
    $self->tidyall(
        conf   => { argv => '-npro -bl' },
        source => $source,
        expect_tidy => 'if ($foo)\n{\n    my $bar = $baz;\n}\n'
    );
    $self->tidyall(
        conf      => { argv => '-npro' },
        source    => 'if ($foo) {\n    my $bar = $baz;\n}\n',
        expect_ok => 1
    );
    $self->tidyall(
        conf         => { argv => '-npro' },
        source       => 'if ($foo) {\n    my $bar = $baz;\n',
        expect_error => qr/Final nesting depth/
    );
    $self->tidyall(
        conf         => { argv => '-npro --badoption' },
        source       => $source,
        expect_error => qr/Unknown option: badoption/
    );
}

1;
