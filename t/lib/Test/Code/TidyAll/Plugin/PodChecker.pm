package Test::Code::TidyAll::Plugin::PodChecker;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    $self->tidyall(
        source    => '=head1 DESCRIPTION\n\nHello',
        expect_ok => 1,
        desc      => 'ok',
    );
    $self->tidyall(
        source       => '=head1 METHODS\n\n=over\n\n=item * foo\n\n',
        expect_error => qr/without closing =back/,
        desc         => 'error',
    );
    $self->tidyall(
        source    => '=head1 DESCRIPTION\n\n=head1 METHODS\n\n',
        expect_ok => 1,
        desc      => 'ok - empty section, no warnings',
    );
    $self->tidyall(
        source       => '=head1 DESCRIPTION\n\n=head1 METHODS\n\n',
        conf         => { warnings => 1 },
        expect_error => qr/empty section in previous paragraph/,
        desc         => 'error - empty section, warnings=1',
    );
    $self->tidyall(
        source    => '=head1 DESCRIPTION\n\nblah blah\n\n=head1 DESCRIPTION\n\nblah blah',
        conf      => { warnings => 1 },
        expect_ok => 1,
        desc      => 'ok - duplicate section, warnings=1',
    );
    $self->tidyall(
        source       => '=head1 DESCRIPTION\n\nblah blah\n\n=head1 DESCRIPTION\n\nblah blah',
        conf         => { warnings => 2 },
        expect_error => qr/multiple occurrence/,
        desc         => 'error - duplicate section, warnings=2',
    );
}

1;
