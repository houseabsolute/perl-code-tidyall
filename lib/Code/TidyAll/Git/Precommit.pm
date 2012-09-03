package Code::TidyAll::Git::Precommit;
use Capture::Tiny qw(capture_stdout capture_stderr);
use Code::TidyAll;
use Code::TidyAll::Util qw(dirname mkpath realpath tempdir_simple write_file);
use Cwd qw(cwd);
use Guard;
use Log::Any qw($log);
use IPC::System::Simple qw(capturex run);
use Moo;
use SVN::Look;
use Try::Tiny;

# Public
has 'conf_file'       => ( is => 'ro', default => sub { "tidyall.ini" } );
has 'no_stash'        => ( is => 'ro' );
has 'reject_on_error' => ( is => 'ro' );
has 'tidyall_class'   => ( is => 'ro', default => sub { "Code::TidyAll" } );
has 'tidyall_options' => ( is => 'ro', default => sub { {} } );

sub check {
    my ( $class, %params ) = @_;

    my $fail_msg;

    try {
        my $self          = $class->new(%params);
        my $tidyall_class = $self->tidyall_class;

        # Find conf file at git root
        my $root_dir = capturex( "git", "rev-parse", "--show-toplevel" );
        chomp($root_dir);
        my $conf_file = join( "/", $root_dir, $self->conf_file );
        die "could not find conf file '$conf_file'" unless -f $conf_file;

        # Store the stash, and restore it upon exiting this scope
        unless ( $self->no_stash ) {
            run("git stash -q --keep-index");
            scope_guard { run("git stash pop -q") };
        }

        # Gather file paths to be committed
        my $output = capturex( "git", "status", "--porcelain" );
        my @files = ( $output =~ /^[MA]\s+(.*)/gm );

        my $tidyall = $tidyall_class->new_from_conf_file(
            $conf_file,
            no_cache   => 1,
            check_only => 1,
            mode       => 'commit',
            %{ $self->tidyall_options },
        );
        my @results = $tidyall->process_files( map { "$root_dir/$_" } @files );

        if ( my @error_results = grep { $_->error } @results ) {
            my $error_count = scalar(@error_results);
            $fail_msg = join(
                "\n",
                sprintf(
                    "%d file%s did not pass tidyall check",
                    $error_count, $error_count > 1 ? "s" : ""
                ),
                map { join( ": ", $_->path, $_->msg ) } @error_results
            );
        }
    }
    catch {
        my $error = $_;
        die "Error during pre-commit hook (use --no-verify to skip hook):\n$error";
    };
    die $fail_msg if $fail_msg;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Git::Precommit - Git precommit hook that requires files to be
tidyall'd

=head1 SYNOPSIS

  In .git/hooks/pre-commit:

    #!/usr/bin/perl
    use Code::TidyAll::Git::Precommit;
    use strict;
    use warnings;
    
    Code::TidyAll::Git::Precommit->check();

=head1 DESCRIPTION

This module implements a L<Git pre-commit
hook|http://git-scm.com/book/en/Customizing-Git-Git-Hooks> that checks if all
files are tidied and valid according to L<tidyall|tidyall>, and rejects the
commit if not.

Files are not modified by this hook. If you want to actually tidy files before
commit,

=head1 METHODS

=over

=item check (key/value params...)

Class method. Check that all files being added or modified in this commit are
tidied and valid according to L<tidyall|tidyall>. If not, then the entire
commit is rejected and the reason(s) are output to the client. e.g.

    % git commit -m "fixups" CHI.pm CHI/Driver.pm 
    2 files did not pass tidyall check
    lib/CHI.pm: *** 'PerlTidy': needs tidying
    lib/CHI/Driver.pm: *** 'PerlCritic': Code before strictures are enabled
      at /tmp/Code-TidyAll-0e6K/Driver.pm line 2
      [TestingAndDebugging::RequireUseStrict]

In an emergency the hook can be bypassed by passing --no-verify to commit:

    % git commit --no-verify ...

or you can just move C<.git/hooks/pre-commit> out of the way temporarily.

The configuration file C<tidyall.ini> must be checked into git in the repo root
directory i.e. next to the .git directory.

The hook will stash any changes not in the index beforehand, and restore them
afterwards, via

    git stash -q --keep-index
    ....
    git stash pop -q

This means that if C<tidyall.ini> has uncommitted changes that are not in the
index, they will not affect the tidyall run.

Passes mode = "commit" by default; see L<modes|tidyall/MODES>.

Key/value parameters:

=over

=item no_stash

Don't attempt to stash changes not in the index. This means the hook will
process even files that are not going to be committed.

=item tidyall_class

Subclass to use instead of L<Code::TidyAll|Code::TidyAll>

=item tidyall_options

Hashref of options to pass to the L<Code::TidyAll|Code::TidyAll> constructor

=back

=back

=cut
