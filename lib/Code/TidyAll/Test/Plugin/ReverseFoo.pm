package Code::TidyAll::Test::Plugin::ReverseFoo;
use Code::TidyAll::Util qw(read_file write_file);
use base qw(Code::TidyAll::Plugin);
use strict;
use warnings;

sub defaults {
    return { include => qr/foo[^\/]+$/ };
}

sub process_file {
    my ( $self, $file ) = @_;
    write_file( $file, scalar( reverse( read_file($file) ) ) );
}

1;
