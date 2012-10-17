package Code::TidyAll::t::Plugin::PHPCodeSniffer;
use Test::Class::Most parent => 'Code::TidyAll::t::Plugin';

sub test_filename { 'foo.php' }

sub test_main : Tests {
    my $self   = shift;
    my $cmd    = '/usr/local/pear/bin/phpcs';
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
