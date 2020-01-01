package TestFor::Code::TidyAll::Plugin::GenericValidator;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';
use FindBin qw( $Bin );
use Path::Tiny qw( path );

sub test_main : Tests {
    my $self = shift;

    my $cmd = join q{ }, $self->_this_perl, path( $Bin, qw( helper-bin generic-validator.pl ) );

    $self->tidyall(
        source    => 'this text is ok',
        expect_ok => 1,
        desc      => 'text does not contain forbidden word',
        conf      => {
            cmd => $cmd,
        },
    );
    $self->tidyall(
        source       => 'this text is forbidden',
        expect_error => qr/exited with 1/,
        desc         => 'text does contain forbidden word',
        conf         => {
            cmd => $cmd,
        },
    );

    my $exit = join q{ }, $self->_this_perl, path( $Bin, qw( helper-bin exit.pl ) );
    $self->tidyall(
        source    => 'this text is fine',
        expect_ok => 1,
        desc      => 'exit code of 2 is ok',
        conf      => {
            cmd           => "$exit 2",
            ok_exit_codes => [ 0, 1, 2 ],
        },
    );
    $self->tidyall(
        source       => 'this text is fine',
        expect_error => qr/exited with 3/,
        desc         => 'exit code of 3 is an exception',
        conf         => {
            cmd           => "$exit 3",
            ok_exit_codes => [ 0, 1, 2 ],
        },
    );
}

1;
