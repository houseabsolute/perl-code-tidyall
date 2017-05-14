package TestFor::Code::TidyAll::Plugin::PHPCodeSniffer;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub test_filename {'foo.php'}

sub _extra_path {
    'php5/usr/bin';
}

sub test_main : Tests {
    my $self = shift;

    return unless $self->require_executable('php');
    return unless $self->require_executable('phpcs');

    my $source = '<?php function foo() { $bar = 5 } ?>';

    $self->tidyall(
        source    => $source,
        conf      => { argv => '--severity=6' },
        expect_ok => 1,
    );
    $self->tidyall(
        source       => $source,
        conf         => { argv => '--severity=3' },
        expect_error => qr/Missing .* doc/,
    );
    $self->tidyall(
        source       => $source,
        conf         => { argv => '--blahblah' },
        expect_error => qr/not known/,
    );
}

1;
