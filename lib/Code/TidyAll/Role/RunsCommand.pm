package Code::TidyAll::Role::RunsCommand;

use strict;
use warnings;

use IPC::Run3 qw(run3);
use List::SomeUtils qw(any);
use Specio::Library::Builtins;
use Specio::Library::Numeric;
use Text::ParseWords qw(shellwords);
use Try::Tiny;

use Moo::Role;

our $VERSION = '0.75';

has ok_exit_codes => (
    is      => 'ro',
    isa     => t( 'ArrayRef', of => t('PositiveOrZeroInt') ),
    default => sub { [0] },
);

# We will end up getting $self->argv from the Plugin base class.

sub _run_or_die {
    my $self = shift;
    my @argv = @_;

    my $output;
    my @cmd = ( shellwords( $self->cmd ), shellwords( $self->argv ), @argv );
    try {
        local $?;
        run3( \@cmd, \undef, \$output, \$output );
        my $code = $? >> 8;
        if ( $self->_is_bad_exit_code($code) ) {
            my $signal = $? & 127;
            my $msg    = "exited with $code";
            $msg .= " - received signal $signal" if $signal;
            $msg .= " - output was:\n$output"    if defined $output and length $output;
            die "$msg\n";
        }
    }
    catch {
        die sprintf(
            "%s failed\n    %s",
            ( join q{ }, @cmd ),
            $_,
        );
    };

    return $output;
}

sub _is_bad_exit_code {
    my $self = shift;
    my $code = shift;

    return !( any { $code == $_ } @{ $self->ok_exit_codes } );
}

1;

# ABSTRACT: A role for plugins which run external commands

__END__

=pod

=encoding UTF-8

=head1 SYNOPSIS

    package Whatever;
    use Moo;
    with 'Code::TidyAll::Role::RunsCommand';

=head1 DESCRIPTION

This is a a role for plugins which run external commands

=head1 ATTRIBUTES

=over

=item cmd

The command to run. This is just the executable and should not include
additional arguments.

=back

=cut

=head1 METHODS

=head2 _run_or_die(@argv)

This method run the plugin's command, combining any values provided to the
plugin's C<argv> attribute with those passed to the method.

The plugin's C<argv> attribute is parsed with the C<shellwords> subroutine from
L<Text::ParseWords> in order to turn the C<argv> string into a list. This
ensures that running the command does not spawn an external shell.

The C<@argv> passed to the command comes after the values from C<argv>
attribute. The assumption is that this will be what passes a file or source
string to the external command.

If the command exits with a non-zero status, then this method throws an
exception. The error message it throws include the command that was run (with
arguments), the exit status, any signal received by the command, and the
command's output.

Both C<stdout> and C<stderr> from the command are combined into a single string
returned by the method.

=head2 _is_bad_exit_code($code)

This method returns true if the exit code is bad and false otherwise. By
default all non-zero codes are bad, but some programs may be expected to exit
non-0 when they encounter validation/tidying issues.

=cut
