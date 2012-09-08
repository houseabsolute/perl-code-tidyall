package Code::TidyAll::t::Plugin::JSHint;
use Code::TidyAll::Util qw(write_file);
use Test::Class::Most parent => 'Code::TidyAll::t::Plugin';

sub test_filename { 'foo.js' }

sub test_main : Tests {
    my $self = shift;

    my $rc_file = $self->{root_dir} . "/jshint.json";

    $self->tidyall(
        source    => 'var my_object = {};',
        expect_ok => 1
    );
    $self->tidyall(
        source       => 'var my_object = new Object();',
        expect_error => qr/object literal notation/
    );
    write_file( $rc_file, '{"camelcase": true}' );
    $self->tidyall(
        source       => 'var my_object = {};',
        conf         => { argv => "--config $rc_file" },
        expect_error => qr/not in camel case/
    );
}

1;
