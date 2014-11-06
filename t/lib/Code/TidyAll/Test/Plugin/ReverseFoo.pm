package Code::TidyAll::Test::Plugin::ReverseFoo;

use File::Slurp::Tiny qw(read_file write_file);
use Moo;
extends 'Code::TidyAll::Plugin';

sub transform_file {
    my ( $self, $file ) = @_;
    write_file( $file, scalar( reverse( read_file($file) ) ) );
}

1;
