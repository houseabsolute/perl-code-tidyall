package TestFor::Code::TidyAll::Plugin::JSLint;

use Path::Tiny qw( cwd );
use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub test_filename {'foo.js'}

sub _extra_path {
    cwd()->child(qw( node_modules .bin ));
}

sub test_main : Tests {
    my $self = shift;

    return unless $self->require_executable('node');
    return unless $self->require_executable('jslint');

    $self->tidyall(
        source    => 'var my_object = {};',
        expect_ok => 1,
        desc      => 'ok',
    );
    $self->tidyall(
        source       => 'while (true) {\nvar i = 5;\n}',
        expect_error => qr/Expected 'var' at column 5/,
        desc         => 'error - bad indentation'
    );
    $self->tidyall(
        source    => 'var i; while (true) {\ni = 5;\n}',
        conf      => { argv => '--white' },
        expect_ok => 1,
        desc      => 'ok - bad indentation, --white'
    );
}

1;
