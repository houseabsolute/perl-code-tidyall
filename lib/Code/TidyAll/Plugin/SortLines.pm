package Code::TidyAll::Plugin::SortLines;

use Moo;
extends 'Code::TidyAll::Plugin';

our $VERSION = '0.34';

sub transform_source {
    my ( $self, $source ) = @_;

    return join( "\n", sort( grep {/\S/} split( /\n/, $source ) ) ) . "\n";
}

1;

# ABSTRACT: Sort the lines in a file

__END__

=pod

=head1 SYNOPSIS

   # In configuration:

   [SortLines]
   select = .ispell* **/.gitignore

=head1 DESCRIPTION

Sorts the lines of a file; whitespace lines are discarded. Useful for files
containing one entry per line, such as C<.svnignore>, C<.gitignore>, and
C<.ispell*>.

