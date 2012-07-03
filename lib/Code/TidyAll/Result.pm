package Code::TidyAll::Result;
use strict;
use warnings;

use Object::Tiny qw(msg state);

sub error { return $_[0]->state eq 'error' }
sub ok { return $_[0]->state ne 'error' }

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Result - Result returned from Code::TidyAll methods

=head1 METHODS

=over

=item error_count

The number of errors that occurred.

=item ok

Returns true iff there were no errors.

=back
