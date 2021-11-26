package Code::TidyAll::Cache;

use strict;
use warnings;

use Digest::SHA qw(sha1_hex);
use Path::Tiny qw(path);
use Specio::Library::Path::Tiny;

use Moo;

our $VERSION = '0.80';

has cache_dir => (
    is       => 'ro',
    isa      => t('Path'),
    required => 1,
);

sub get {
    my ( $self, $key ) = @_;

    my $file = $self->_path_for_key($key);
    if ( $file->exists ) {
        return $file->slurp_raw;
    }
    else {
        return undef;
    }
}

sub set {
    my ( $self, $key, $value ) = @_;

    my $file = $self->_path_for_key($key);
    $file->parent->mkpath( { mode => 0755 } );
    $file->spew_raw($value);

    return;
}

sub remove {
    my ( $self, $key, $value ) = @_;

    $self->_path_for_key($key)->remove;

    return;
}

sub _path_for_key {
    my ( $self, $key ) = @_;

    my $sig = sha1_hex($key);
    return $self->cache_dir->child( substr( $sig, 0, 1 ), "$sig.dat" );
}

1;

# ABSTRACT: A simple caching engine which stores key/value pairs
