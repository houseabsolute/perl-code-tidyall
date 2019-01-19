package TestFor::Code::TidyAll::Plugin::GenericValidator;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub _mswin_compat {
    my $cmd = shift;

    # Get the tests to pass on windows due to shellwords()
    $cmd =~ s#\\#/#g;
    return $cmd;
}

sub test_main : Tests {
    my $self = shift;

    my $val = _mswin_compat(qq{$^X t/lib/progs/validator1.pl});

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
            cmd           => _mswin_compat(qq{$^X -e "exit 2"}),
            ok_exit_codes => [ 0, 1, 2 ],
        },
    );
    $self->tidyall(
        source       => 'this text is fine',
        expect_error => qr/exited with 3/,
        desc         => 'exit code of 3 is an exception',
        conf         => {
            cmd           => _mswin_compat(qq{$^X -e "exit 3"}),
            ok_exit_codes => [ 0, 1, 2 ],
        },
    );
}

1;
