package TestFor::Code::TidyAll::Plugin::GenericTransformer;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $trans
        = $^X
        . q{ -MPath::Tiny=path -e 'my $content = path(shift)->slurp; $content =~ s/forbidden/safe/i; print $content'};
    $self->tidyall(
        source    => 'this text is unchanged',
        expect_ok => 1,
        desc      => 'text not containing forbidden word is unchanged',
        conf      => {
            cmd => $trans,
        },
    );
    $self->tidyall(
        source      => 'this text is forbidden',
        expect_tidy => 'this text is safe',
        desc        => 'text containing forbidden word is transformed',
        conf        => {
            cmd => $trans,
        },
    );
    $self->tidyall(
        source       => 'this text is fine',
        expect_error => qr/exited with 3/,
        desc         => 'exit code of 3 is an exception',
        conf         => {
            cmd           => qq{$^X -e 'exit 3'},
            ok_exit_codes => [ 0, 1, 2 ],
        },
    );
}

1;
