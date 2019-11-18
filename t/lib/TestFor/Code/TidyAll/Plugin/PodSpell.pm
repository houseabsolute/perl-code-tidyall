package TestFor::Code::TidyAll::Plugin::PodSpell;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub test_filename {'Foo.pod'}

sub test_main : Tests {
    my $self = shift;

    if ( $^O eq 'MSWin32' ) {
        $self->builder->skip('There is no ispell on Windows');
        return;
    }

    my $dict_file = $self->{root_dir}->child('.ispell_english');

    $self->tidyall(
        source    => '=head SUMMARY\n\nthe quick brown fox jumped over the lazy dogs',
        expect_ok => 1,
        desc      => 'ok',
    );
    $self->tidyall(
        source       => '=head SUMMARY\n\nthe quick browwn fox jumped over the lazeey dogs',
        expect_error => qr/unrecognized words:\nbrowwn\nlazeey/,
        desc         => 'spelling mistakes',
    );
    $dict_file->spew("browwn\n");
    $self->tidyall(
        source       => '=head SUMMARY\n\nthe quick browwn fox jumped over the lazeey dogs',
        conf         => { ispell_argv => "-p $dict_file" },
        expect_error => qr/unrecognized words:\nlazeey/,
        desc         => 'spelling mistakes, one in dictionary',
    );
    $dict_file->spew("browwn\nlazeey\n");
    $self->tidyall(
        source    => '=head SUMMARY\n\nthe quick browwn fox jumped over the lazeey dogs',
        conf      => { ispell_argv => "-p $dict_file" },
        expect_ok => 1,
        desc      => 'spelling mistakes, all in dictionary',
    );
}

1;
