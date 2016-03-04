package Code::TidyAll::Role::Tempdir;

use Moo::Role;

use Cwd qw(realpath);
use File::Temp qw(tempdir);

our $VERSION = '0.42';

has '_tempdir'   => ( is => 'ro', lazy => 1, builder => 1 );
has 'no_cleanup' => ( is => 'ro', default => 0 );

sub _build__tempdir {
    my ($self) = @_;
    return realpath(
        tempdir(
            'Code-TidyAll-XXXX',
            TMPDIR  => 1,
            CLEANUP => !$self->no_cleanup,
        )
    );
}

1;

# ABSTRACT: Provides a _tempdir attribute for Code::TidyAll classes

__END__

=pod

=encoding UTF-8

=head1 SYNOPSIS

    package Whatever;
    use Moo;
    with 'Code::TidyAll::Role::Tempdir';

=head1 DESCRIPTION

A role to add tempdir attributes to classes.

=head1 ATTRIBUTES

=over

=item _tempdir

The temp directory. Lazily constructed if not passed

=item no_cleanup

A boolean indicating if the temp directory created by the C<_tempdir> builder
should not automatically clean up after itself

=back

=cut
