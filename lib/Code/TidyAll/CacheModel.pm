package Code::TidyAll::CacheModel;

use strict;
use warnings;

use Digest::SHA qw(sha1_hex);
use Path::Tiny ();
use Specio::Declare;
use Specio::Library::Builtins;
use Specio::Library::Path::Tiny;
use Specio::Library::String;

use Moo;

our $VERSION = '0.66';

has base_sig => (
    is      => 'ro',
    isa     => t('Str'),
    default => q{},
);

has cache_engine => (
    is  => 'ro',
    isa => object_can_type(
        methods => [qw( get set remove )],
    ),
    predicate => '_has_cache_engine',
);

has cache_key => (
    is      => 'lazy',
    isa     => t('NonEmptyStr'),
    clearer => 1,
);

has cache_value => (
    is      => 'lazy',
    isa     => t('NonEmptyStr'),
    clearer => 1,
);

has file_contents => (
    is      => 'rw',
    isa     => t('Str'),
    lazy    => 1,
    builder => 1,
    trigger => 1,
    clearer => 1,
);

has full_path => (
    is       => 'ro',
    isa      => t('Path'),
    required => 1,
);

has is_cached => (
    is      => 'rw',
    isa     => t('Bool'),
    lazy    => 1,
    builder => 1,
    clearer => 1,
);

has path => (
    is       => 'ro',
    isa      => t('Path'),
    required => 1,
);

sub _build_file_contents {
    my ($self) = @_;
    return Path::Tiny::path( $self->full_path )->slurp;
}

sub _trigger_file_contents {
    my $self = shift;
    $self->clear_cache_key;
    $self->clear_is_cached;
    $self->clear_cache_value;
    return;
}

sub _build_cache_key {
    my ($self) = @_;
    return 'sig/' . $self->path;
}

sub _build_cache_value {
    my ($self) = @_;

    # this stat isn't ideal, but it'll do
    my $last_mod = ( stat( $self->full_path ) )[9];
    return $self->_sig( [ $self->base_sig, $last_mod, $self->file_contents ] );
}

sub _build_is_cached {
    my ($self) = @_;

    return unless $self->_has_cache_engine;
    my $cached_value = $self->cache_engine->get( $self->cache_key );
    return defined $cached_value && $cached_value eq $self->cache_value;
}

sub update {
    my ($self) = @_;

    return unless $self->_has_cache_engine;
    $self->cache_engine->set( $self->cache_key, $self->cache_value );
    $self->is_cached(1);
    return;
}

sub remove {
    my ($self) = @_;

    return unless $self->_has_cache_engine;
    $self->cache_engine->remove( $self->cache_key );
    return;
}

sub _sig {
    my ( $self, $data ) = @_;
    return sha1_hex( join( ',', @$data ) );
}

1;

# ABSTRACT: Caching model for Code::TidyAll

__END__

=pod

=head1 SYNOPSIS

  my $cache_model = Cody::TidyAll::CacheModel->new(
      cache_engine => Code::TidyAll::Cache->new(...),
      path         => '/path/to/file/to/cache',
  );

  # check cache
  print 'Yes!' if $cache_model->is_cached;

  # update cache
  $cache_model->clear_file_contents;
  $cache_model->update;

  # update the cache when you know the file contents
  $cache_model->file_contents($new_content);
  $cache_model->update;

  # force removal from cache
  $cache_model->remove;

=head1 DESCRIPTION

A cache model for Code::TidyAll. Different subclasses can employ different
caching techniques.

The basic model implemented here is simple;  It stores in the cache a hash key
of the file contents keyed by a hash key of the file's path.

=head2 Attributes

=over

=item full_path (required, ro)

The full path to the file on disk

=item path (required, ro)

The local path to the file (i.e. what the cache system will consider the
canonical name of the file)

=item cache_engine (optional, default undef, ro)

A C<Code::TidyAll::Cache> compatible instance, or, if no caching is required
undef.

=item base_sig (optional, default empty string, ro)

A base signature.

=item file_contents (optional, default loads file contents from disk, rw)

=item is_cached (optional, default computed, rw)

A flag indicating if this is cached. By default checks that the cache key and
cache value match the cache.

=back

=head2 Methods

=over

=item cache_key

The computed cache key for the file

=item cache_value

The computed cache value for the file

=item update

Updates the cache

=item remove

Attempts to remove the value from the cache

=back

=cut
