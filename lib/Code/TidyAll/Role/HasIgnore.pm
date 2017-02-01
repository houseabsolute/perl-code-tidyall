package Code::TidyAll::Role::HasIgnore;

use strict;
use warnings;

use Code::TidyAll::Util::Zglob qw(zglobs_to_regex);
use Specio::Library::Builtins;
use Specio::Library::String;

use Moo::Role;

our $VERSION = '0.57';

has 'ignore' => (
    is  => 'ro',
    isa => t( 'ArrayRef', of => t('NonEmptyStr') ),
    default => sub { [] },
);

has 'ignore_regex' => ( is => 'lazy' );
has 'ignores'      => ( is => 'lazy' );
has 'select_regex' => ( is => 'lazy' );
has 'selects'      => ( is => 'lazy' );

sub _build_ignores {
    my ($self) = @_;
    return $self->_parse_zglob_list( $self->ignore );
}

sub _parse_zglob_list {
    my ( $self, $zglobs ) = @_;
    if ( my ($bad_zglob) = ( grep {m{^/}} @{$zglobs} ) ) {
        die "zglob '$bad_zglob' should not begin with slash";
    }
    return $zglobs;
}

sub _build_ignore_regex {
    my ($self) = @_;
    return zglobs_to_regex( @{ $self->ignores } );
}

1;
