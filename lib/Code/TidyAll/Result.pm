package Code::TidyAll::Result;

use strict;
use warnings;

use Moo;

our $VERSION = '0.59';

has 'error'         => ( is => 'ro' );
has 'new_contents'  => ( is => 'ro' );
has 'orig_contents' => ( is => 'ro' );
has 'path'          => ( is => 'ro' );
has 'state'         => ( is => 'ro' );

sub ok { return $_[0]->state ne 'error' }

1;

# ABSTRACT: Result returned from processing a file/source

__END__

=pod

=head1 SYNOPSIS

    my $ct = Code::TidyAll->new(...);
    my $result = $ct->process_file($file);
    if ($result->error) {
       ...
    }

=head1 DESCRIPTION

Represents the result of
L<Code::TidyAll::process_file|Code::TidyAll/process_file> and
L<Code::TidyAll::process_file|Code::TidyAll/process_source>. A list of these is
returned from L<Code::TidyAll::process_paths|Code::TidyAll/process_paths>.

=head1 METHODS

=over

=item path

The path that was processed, relative to the root (e.g. "lib/Foo.pm")

=item state

A string, one of

=over

=item C<no_match> - No plugins matched this file

=item C<cached> - Cache hit (file had not changed since last processed)

=item C<error> - An error occurred while applying one of the plugins

=item C<checked> - File was successfully checked and did not change

=item C<tidied> - File was successfully checked and changed

=back

=item orig_contents

Contains the original contents if state is 'tidied' and with some errors (like
when a file needs tidying in check-only mode)

=item new_contents

Contains the new contents if state is 'tidied'

=item error

Contains the error message if state is 'error'

=item ok

Returns true iff state is not 'error'

=back
