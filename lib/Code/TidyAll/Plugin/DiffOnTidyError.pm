package Code::TidyAll::Plugin::DiffOnTidyError;

use strict;
use warnings;

use File::Basename qw( basename );
use File::Which qw( which );
use IPC::Run3 qw( run3 );
use Moo;

our $VERSION = '0.33';

extends 'Code::TidyAll::Plugin';
with 'Code::TidyAll::Role::Tempdir';

sub diff {
    my $self = shift;
    my $diff = shift;
    my $orig = shift;
    my $new  = shift;
    my $path = shift;

    my $cmd = which('diff');
    die 'Could not find a diff command in your $PATH'
        unless $cmd;

    my $orig_file = $self->_write_temp_file( basename($path) . '.orig', $orig );
    my $new_file  = $self->_write_temp_file( basename($path) . '.new',  $new );

    my $output;
    run3(
        [ $cmd, '-u', $orig_file, $new_file ],
        \undef,
        \$output,
        \$output,
    );

    return $output;
}

1;

# ABSTRACT: Include a diff in error message when code needs tidying

__END__

=pod

=head1 SYNOPSIS

   # In configuration:

   [DiffOnTidyError]
   select = **/*

=head1 DESCRIPTION

When running L<Code::TidyAll> in C<check_only> mode, for example via
L<Test::Code::TidyAll>, this plugin adds a diff to the output when a file needs
to be tidied. This plugin uses the F<diff> command, and will simply die if it
cannot find one in your C<$PATH>.

This is helpful if you're trying to figure out what a test is failing on.

=cut
