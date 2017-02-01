package TestHelper::Plugin::ReverseFoo;

use Path::Tiny qw(path);
use Moo;
extends 'Code::TidyAll::Plugin';

sub transform_file {
    my ( $self, $file ) = @_;
    $file->spew( scalar( reverse( $file->slurp ) ) );
}

1;
