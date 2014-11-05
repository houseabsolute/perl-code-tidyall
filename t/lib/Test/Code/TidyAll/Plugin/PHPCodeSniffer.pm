package Test::Code::TidyAll::Plugin::PHPCodeSniffer;

use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_filename { 'foo.php' }

sub test_main : Tests {
    my $self   = shift;

    local $ENV{PATH} = $ENV{PATH};
    $ENV{PATH} .= ':/usr/local/pear/bin'
        unless $ENV{PATH} =~ q{/usr/local/pear/bin};

    $self->require_executable('phpcs');

    my $source = '<?php function foo() { $bar = 5 } ?>';

    $self->tidyall(
        source    => $source,
        conf      => { cmd => $cmd, argv => "--severity=6" },
        expect_ok => 1,
    );
    $self->tidyall(
        source       => $source,
        conf         => { cmd => $cmd, argv => "--severity=3" },
        expect_error => qr/Missing .* doc/,
    );
    $self->tidyall(
        source       => $source,
        conf         => { cmd => $cmd, argv => "--blahblah" },
        expect_error => qr/not known/,
    );
}

1;
