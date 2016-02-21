package Code::TidyAll::Cache;

use Digest::SHA qw(sha1_hex);
use Code::TidyAll::Util qw(dirname mkpath);
use File::Slurp::Tiny qw(read_file write_file);
use Moo;

our $VERSION = '0.41';

has 'cache_dir' => ( is => 'ro', required => 1 );

sub path_to_key {
    my ( $self, $key ) = @_;
    my $sig = sha1_hex($key);
    return join( "/", $self->cache_dir, substr( $sig, 0, 1 ), "$sig.dat" );
}

sub get {
    my ( $self, $key ) = @_;

    my $file = $self->path_to_key($key);
    if ( defined $file && -f $file ) {
        return read_file($file);
    }
    else {
        return undef;
    }
}

sub set {
    my ( $self, $key, $value ) = @_;

    my $file = $self->path_to_key($key);
    mkpath( dirname($file), 0, 0775 );
    write_file( $file, $value );
}

sub remove {
    my ( $self, $key, $value ) = @_;

    my $file = $self->path_to_key($key);
    unlink($file);
}

1;
