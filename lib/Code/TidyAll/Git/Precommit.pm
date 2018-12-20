package Code::TidyAll::Git::Precommit;

use strict;
use warnings;

use Capture::Tiny qw(capture_stdout capture_stderr);
use Code::TidyAll::Git::Util qw(git_files_to_commit);
use Code::TidyAll;
use IPC::System::Simple qw(capturex run);
use Log::Any qw($log);
use Path::Tiny qw(path);
use Scope::Guard qw(guard);
use Specio::Library::Builtins;
use Specio::Library::String;
use Try::Tiny;

use Moo;

our $VERSION = '0.73';

has conf_name => (
    is  => 'ro',
    isa => t('NonEmptyStr'),
);

has git_path => (
    is      => 'ro',
    isa     => t('NonEmptyStr'),
    default => 'git'
);

has no_stash => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
);

has tidyall_class => (
    is      => 'ro',
    isa     => t('ClassName'),
    default => 'Code::TidyAll'
);

has tidyall_options => (
    is      => 'ro',
    isa     => t('HashRef'),
    default => sub { {} }
);

sub check {
    my ( $class, %params ) = @_;

    my $fail_msg;

    try {
        my $self          = $class->new(%params);
        my $tidyall_class = $self->tidyall_class;

        # Find conf file at git root
        my $root_dir = capturex( $self->git_path, qw( rev-parse --show-toplevel ) );
        chomp($root_dir);
        $root_dir = path($root_dir);

        my @conf_names
            = $self->conf_name ? ( $self->conf_name ) : Code::TidyAll->default_conf_names;
        my ($conf_file) = grep { $_->is_file } map { $root_dir->child($_) } @conf_names
            or die sprintf( 'could not find conf file %s', join( ' or ', @conf_names ) );

        my $guard;
        unless ( $self->no_stash ) {

            # We stash things to make sure that we only attempt to run tidyall
            # on changes in the index while ensuring that after the hook runs
            # the working directory is in the same state it was before the
            # commit.
            #
            # If there's nothing to stash there's no stash entry, in which
            # case popping would be very bad.
            my $output = capturex(
                $self->git_path, qw( stash save --keep-index --include-untracked ),
                'TidyAll pre-commit guard'
            );
            $guard = guard { run( $self->git_path, 'stash', 'pop', '-q' ) }
            unless $output =~ /No local changes/;
        }

        # Gather file paths to be committed
        my @files = git_files_to_commit($root_dir);

        my $tidyall = $tidyall_class->new_from_conf_file(
            $conf_file,
            no_cache   => 1,
            check_only => 1,
            mode       => 'commit',
            %{ $self->tidyall_options },
        );
        my @results = $tidyall->process_paths(@files);

        if ( my @error_results = grep { $_->error } @results ) {
            my $error_count = scalar(@error_results);
            $fail_msg = sprintf(
                "%d file%s did not pass tidyall check\n",
                $error_count, $error_count > 1 ? 's' : q{}
            );
        }
    }
    catch {
        my $error = $_;
        die "Error during pre-commit hook (use --no-verify to skip hook):\n$error";
    };
    die "$fail_msg\n" if $fail_msg;
}

1;

# ABSTRACT: Git pre-commit hook that requires files to be tidyall'd

__END__

=pod

=head1 SYNOPSIS

  In .git/hooks/pre-commit:

    #!/usr/bin/env perl
    use strict;
    use warnings;

    use Code::TidyAll::Git::Precommit;
    Code::TidyAll::Git::Precommit->check();

=head1 DESCRIPTION

This module implements a L<Git pre-commit
hook|http://git-scm.com/book/en/Customizing-Git-Git-Hooks> that checks if all
files are tidied and valid according to L<tidyall>, and rejects the commit if
not. Files/commits are never modified by this hook.

See also L<Code::TidyAll::Git::Prereceive>, which validates pushes to a shared
repo.

=head1 METHODS

This class provides one method:

=head2 Code::TidyAll::Git::Precommit->check(%params)

Checks that all files being added or modified in this commit are tidied and
valid according to L<tidyall>. If not, then the entire commit is rejected and
the reason(s) are output to the client. e.g.

    % git commit -m "fixups" CHI.pm CHI/Driver.pm
    2 files did not pass tidyall check
    lib/CHI.pm: *** 'PerlTidy': needs tidying
    lib/CHI/Driver.pm: *** 'PerlCritic': Code before strictures are enabled
      at /tmp/Code-TidyAll-0e6K/Driver.pm line 2
      [TestingAndDebugging::RequireUseStrict]

In an emergency the hook can be bypassed by passing --no-verify to commit:

    % git commit --no-verify ...

or you can just move C<.git/hooks/pre-commit> out of the way temporarily.

The configuration file (C<tidyall.ini> or C<.tidyallrc>) must be checked into
git in the repo root directory i.e. next to the .git directory.

By default, the hook will stash any changes not in the index beforehand, and
restore them afterwards, via

    git stash save --keep-index --include-untracked
    ....
    git stash pop

This means that if the configuration file has uncommitted changes that are not
in the index, they will not affect the tidyall run.

This class passes mode = "commit" by default to tidyall; see
L<modes|tidyall/MODES>.

Key/value parameters:

=over 4

=item * conf_name

A conf file name to search for instead of the defaults.

=item * git_path

Path to git to use in commands, e.g. '/usr/bin/git' or '/usr/local/bin/git'. By
default, it just uses 'git', which will search the user's C<PATH>.

=item * no_stash

Don't attempt to stash changes not in the index. This means the hook will
process files that are not going to be committed.

=item * tidyall_class

Subclass to use instead of L<Code::TidyAll>.

=item * tidyall_options

A hashref of options to pass to the L<Code::TidyAll> constructor.

=back

=head1 USING AND (NOT) ENFORCING THIS HOOK

This hook must be placed manually in each copy of the repo - there is no way to
automatically distribute or enforce it. However, you can make things easier on
yourself or your developers as follows:

=over

=item *

Create a directory called C<git/hooks> at the top of your repo (note no dot
prefix).

    mkdir -p git/hooks

=item *

Commit your pre-commit script in C<git/hooks/pre-commit> containing:

    #!/usr/bin/env perl

    use strict;
    use warnings;

    use Code::TidyAll::Git::Precommit;
    Code::TidyAll::Git::Precommit->check();

=item *

Add a setup script in C<git/setup.sh> containing

    #!/bin/bash
    chmod +x git/hooks/pre-commit
    cd .git/hooks
    ln -s ../../git/hooks/pre-commit

=item *

Run C<git/setup.sh> (or tell your developers to run it) once for each new clone
of the repo

=back

See L<this Stack Overflow
question||http://stackoverflow.com/questions/3703159/git-remote-shared-pre-commit-hook>
for more information on pre-commit hooks and the impossibility of enforcing
their use.

See also L<Code::TidyAll::Git::Prereceive>, which enforces tidyall on pushes to
a remote shared repository.

=cut
