package TestFor::Code::TidyAll::Plugin::GenericTransformer;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';
use Path::Tiny qw( path );

sub test_main : Tests {
    my $self = shift;

    my $cmd_text = $self->_this_perl . ' t/helper-bin/generic-transformer.pl';
    my $cmd_raw  = $self->_this_perl . ' t/helper-bin/raw-transformer.pl';

    my $crlf = "a\r\nb\r\nc\r\n";
    my $lf   = "a\nb\nc\n";

    $self->tidyall(
        source    => 'this text is unchanged',
        expect_ok => 1,
        desc      => 'text not containing forbidden word is unchanged',
        conf      => {
            cmd => $cmd_text,
        },
    );
    $self->tidyall(
        source      => 'this text is forbidden',
        expect_tidy => 'this text is safe',
        desc        => 'text containing forbidden word is transformed',
        conf        => {
            cmd => $cmd_text,
        },
    );

    my $crlf_file = path( $self->{root_dir}, 'crlf' );
    $crlf_file->spew_raw($crlf);
    $self->tidyall(
        source_file => $crlf_file,
        expect_tidy => sprintf( '%v02X', $crlf ),
        desc        => 'generic transformer preserves crlf line endings',
        conf        => {
            cmd => $cmd_raw,
        },
    );

    my $lf_file = path( $self->{root_dir}, 'lf' );
    $lf_file->spew_raw($lf);
    $self->tidyall(
        source_file => $lf_file,
        expect_tidy => sprintf( '%v02X', $lf ),
        desc        => 'generic transformer preserves linefeed line endings',
        conf        => {
            cmd => $cmd_raw,
        },
    );

    $self->tidyall(
        source       => 'this text is fine',
        expect_error => qr/exited with 3/,
        desc         => 'exit code of 3 is an exception',
        conf         => {
            cmd           => $self->_this_perl . ' t/helper-bin/exit.pl 3',
            ok_exit_codes => [ 0, 1, 2 ],
        },
    );
}

1;
