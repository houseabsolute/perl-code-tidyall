package Code::TidyAll::CacheModel::Shared;

use Moo;
extends 'Code::TidyAll::CacheModel';

our $VERSION = '0.25';

sub _build_cache_key {
    my $self = shift;
    return $self->_sig(
        [
            $self->SUPER::_build_cache_key,
            $self->file_contents
        ]
    );
}

sub _build_cache_value {
    return 1;
}

sub remove {
    return;
}

1;

__END__

=head1 NAME

Code::TidyAll:CacheModel::Shared - shared cache model for Code::TidyAll

=head1 SYNOPSIS

   my $cta = Code::TidyAll->new(
     cache_model_class => 'Code::TidyAll::CacheModel::Shared',
     ...
   );

=head1 DESCRIPTION

An alternative caching model for Code::TidyAll designed to work in shared build
systems / systems with lots of branches.

This cache model uses both the file name and file contents to build the cache
key and a meaningless cache value. It does not care about the modification time
of the file.

This allows you to share a cache when you might have several versions of a file
that you switch backwards and forwards between (e.g. when you're working on
several branches) and keep the cache values

