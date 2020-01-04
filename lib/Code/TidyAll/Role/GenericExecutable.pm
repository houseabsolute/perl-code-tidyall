package Code::TidyAll::Role::GenericExecutable;

use strict;
use warnings;

use IPC::Run3 qw(run3);
use Specio::Library::Builtins;
use Specio::Library::String;
use Text::ParseWords qw(shellwords);
use Try::Tiny;

use Moo::Role;

with 'Code::TidyAll::Role::RunsCommand';

our $VERSION = '0.78';

has '+cmd' => (
    is       => 'ro',
    required => 1,
);

has file_flag => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_file_flag',
);

sub _run_generic_executable_or_die {
    my $self = shift;
    my $file = shift;

    my @argv;
    push @argv, $self->file_flag if $self->_has_file_flag;
    push @argv, $file;

    return $self->_run_or_die(@argv);
}

1;

# ABSTRACT: A role for plugins which allow you to use any executable as a transformer or validator

__END__

=pod

=encoding UTF-8

=head1 SYNOPSIS

    package Whatever;
    use Moo;
    with 'Code::TidyAll::Role::GenericExecutable';

=head1 DESCRIPTION

This role exists for the benefit of the
L<Code::TidyAll::Plugin::GenericTransformer> and
L<Code::TidyAll::Plugin::GenericValidator> plugin classes.

=head1 ATTRIBUTES

=over

=item cmd

This attribute is require for any class which consumes this role.

=item file_flag

If this is set then this flag is used to indicate the file passed to the
command, for example something like C<-f>, C<--file>, or C<--input>. By
default, the file is simply passed as the last argument to the command.

=back

=cut
