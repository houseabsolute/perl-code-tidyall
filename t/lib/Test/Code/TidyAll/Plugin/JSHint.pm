package Test::Code::TidyAll::Plugin::JSHint;

use File::Slurp::Tiny qw(write_file);
use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';

sub test_filename { 'foo.js' }

sub _extra_path {
    'node_modules/.bin';
}

sub test_main : Tests {
    my $self = shift;

    $self->require_executable('node');

    $self->tidyall(
        source    => 'var my_object = {};',
        expect_ok => 1,
        desc      => 'ok - camelcase',
    );
    $self->tidyall(
        source    => 'while (day)\n  shuffle();',
        expect_ok => 1,
        desc      => 'ok no brace',
    );
    $self->tidyall(
        source       => 'var my_object = new Object();',
        expect_error => qr/object literal notation/,
        desc         => 'error - object literal',
    );
    $self->tidyall(
        source       => 'var my_object = {};',
        conf         => { options => 'camelcase' },
        expect_error => qr/not in camel case/,
        desc         => 'error - camel case - options=camelcase',
    );
    $self->tidyall(
        source       => 'var my_object = {};',
        conf         => { options => 'camelcase curly' },
        expect_error => qr/not in camel case/,
        desc         => 'error - camel case - options=camelcase,curly',
    );
    $self->tidyall(
        source       => 'while (day)\n  shuffle();',
        conf         => { options => 'camelcase curly' },
        expect_error => qr/Expected \'{/,
        desc         => 'error - curly - options=camelcase,curly',
    );

    my $rc_file = $self->{root_dir} . "/jshint.json";
    write_file( $rc_file, '{"camelcase": true}' );

    $self->tidyall(
        source       => 'var my_object = {};',
        conf         => { argv => "--config $rc_file" },
        expect_error => qr/not in camel case/,
        desc         => 'error - camelcase - conf file',
    );
    $self->tidyall(
        source       => 'var my_object = {};',
        conf         => { argv => "--badoption" },
        expect_error => qr/Unknown option/,
        desc         => 'error - bad option'
    );
}

1;
