package Code::TidyAll::Cache;
use Object::Tiny qw(cache_dir);
use Digest::SHA1 qw(sha1_hex);
use Code::TidyAll::Util qw(dirname mkpath read_file write_file);
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    die "cache_dir required" unless $self->{cache_dir};
    return $self;
}

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
