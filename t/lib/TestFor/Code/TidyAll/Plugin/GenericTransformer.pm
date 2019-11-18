package TestFor::Code::TidyAll::Plugin::GenericTransformer;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';
use Path::Tiny qw/ path /;

sub test_main : Tests {
    my $self = shift;

    my $cmd = $self->_this_perl . ' t/helper-bin/generic-transformer.pl';
    my $cmd_xform = $self->_this_perl . ' t/helper-bin/generic-xform.pl';

	my $crlf_str = "a\r\nb\r\nc\r\n";
	my $lf_str = "a\nb\nc\n";

    $self->tidyall(
        source_file  => write_file("$self->{root_dir}/crlf", $crlf_str),
        expect_xform => sprintf("%v02X", $crlf_str),
        desc      => 'preserving crlf',
        conf      => {
            cmd => $cmd_xform,
        },
    );
    $self->tidyall(
        source_file    => write_file("$self->{root_dir}/lf", $lf_str),
        expect_xform => sprintf("%v02X", $lf_str),
        desc      => 'preserving lf',
        conf      => {
            cmd => $cmd_xform,
        },
    );
    $self->tidyall(
        source    => 'this text is unchanged',
        expect_ok => 1,
        desc      => 'text not containing forbidden word is unchanged',
        conf      => {
            cmd => $cmd,
        },
    );
    $self->tidyall(
        source      => 'this text is forbidden',
        expect_tidy => 'this text is safe',
        desc        => 'text containing forbidden word is transformed',
        conf        => {
            cmd => $cmd,
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

sub write_file
{
	my $f = shift;
	my $data = shift;
	
	path($f)->spew_raw($data);

	return $f;
}
1;
