package Code::TidyAll::Cache;

use strict;
use warnings;

use Digest::SHA qw(sha1_hex);
use Path::Tiny qw(path);

use Moo;

our $VERSION = '0.57';

has 'cache_dir' => ( is => 'ro', required => 1 );

sub path_to_key {
    my ( $self, $key ) = @_;
    my $sig = sha1_hex($key);
    return $self->cache_dir->child( substr( $sig, 0, 1 ), "$sig.dat" );
}

sub get {
    my ( $self, $key ) = @_;

    my $file = $self->path_to_key($key);
    if ( $file->exists ) {
        return $file->slurp;
    }
    else {
        return undef;
    }
}

sub set {
    my ( $self, $key, $value ) = @_;

    my $file = $self->path_to_key($key);
    $file->parent->mkpath( { mode => 0755 } );
    $file->spew($value);

    return;
}

sub remove {
    my ( $self, $key, $value ) = @_;

    $self->path_to_key($key)->remove;

    return;
}

1;
