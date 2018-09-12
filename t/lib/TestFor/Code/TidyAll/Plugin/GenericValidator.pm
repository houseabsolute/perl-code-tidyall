package TestFor::Code::TidyAll::Plugin::GenericValidator;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $val = qq{$^X -MPath::Tiny=path -e 'exit 1 if path(shift)->slurp =~ /forbidden/i'};
    $self->tidyall(
        source    => 'this text is ok',
        expect_ok => 1,
        desc      => 'text does not contain forbidden word',
        conf      => {
            cmd => $val,
        },
    );
    $self->tidyall(
        source    => 'this text is forbidden',
        expect_ok => 0,
        desc      => 'text does contain forbidden word',
        conf      => {
            cmd => $val,
        },
    );
    $self->tidyall(
        source    => 'this text is fine',
        expect_ok => 1,
        desc      => 'exit code of 2 is ok',
        conf      => {
            cmd           => qq{$^X -e 'exit 2'},
            ok_exit_codes => [ 0, 1, 2 ],
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
