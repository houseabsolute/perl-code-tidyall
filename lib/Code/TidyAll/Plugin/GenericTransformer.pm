package Code::TidyAll::Plugin::GenericTransformer;

use strict;
use warnings;

use Moo;

extends 'Code::TidyAll::Plugin';

with 'Code::TidyAll::Role::GenericExecutable';

our $VERSION = '0.76';

sub transform_file {
    my $self = shift;
    my $file = shift;

    my $output = $self->_run_generic_executable_or_die($file);
    $file->spew_raw($output);

    return;
}

1;

# ABSTRACT: A plugin to run any executable as a transformer

__END__

=pod

=head1 SYNOPSIS

    # In your tidyall config
    [GenericTransformer / JSONOrderedTidy]
    cmd = json-ordered-tidy
    argv = -stdout
    ok_exit_codes = 0 1

=head1 DESCRIPTION

This plugin allows you to define any executable as a transformer.

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 cmd

This is the command to be run. This is required.

=head2 argv

This is a string containing additional arguments to be passed to the command.
These arguments will always be passed.

=head2 file_flag

This is the flag used to tell the command what file to operate on, if it has
one.

By default, the file is simply passed as the last argument. However, many
commands will want this passed with a flag like C<-f>, C<--file>, or
C<--input>.

=head2 ok_exit_codes

By default, any exit code other than C<0> is considered an exception. However,
many commands use their exit code to indicate that there was a validation issue
as opposed to an exception.

You can specify multiple exit codes either by listing C<ok_exit_codes> multiple
times or as a space-separate list.

