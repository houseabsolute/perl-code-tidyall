package Code::TidyAll::Git::Prereceive;
use Code::TidyAll;
use Code::TidyAll::Util qw(realpath);
use Log::Any qw($log);
use IPC::System::Simple qw(capturex run);
use Moo;
use SVN::Look;
use Try::Tiny;

# Public
has 'conf_file'       => ( is => 'ro', default => sub { "tidyall.ini" } );
has 'git_path'        => ( is => 'ro', default => sub { 'git' } );
has 'reject_on_error' => ( is => 'ro' );
has 'tidyall_class'   => ( is => 'ro', default => sub { "Code::TidyAll" } );
has 'tidyall_options' => ( is => 'ro', default => sub { {} } );

sub check {
    my ( $class, %params ) = @_;

    my $fail_msg;

    try {
        my $self = $class->new(%params);

        my $root_dir = realpath();
        local $ENV{GIT_DIR} = $root_dir;

        my $conf_file = join( "/", $root_dir, $self->conf_file );
        die "could not find conf file '$conf_file'" unless -f $conf_file;

        my $tidyall = $self->tidyall_class->new_from_conf_file(
            $conf_file,
            no_cache   => 1,
            check_only => 1,
            mode       => 'commit',
            %{ $self->tidyall_options },
        );

        $log->info("----------------------------");

        my @results;
        while ( my $line = <> ) {
            chomp($line);
            my ( $base, $commit, $ref ) = split( /\s+/, $line );
            next unless $ref eq 'refs/heads/master';

            my @files = $self->get_changed_files( $base, $commit );
            $log->infof( "base='%s', commit='%s', files=[%s]", $base, $commit,
                join( " ", @files ) );
            foreach my $file (@files) {
                my $contents = $self->get_file_contents( $file, $commit );
                push( @results, $tidyall->process_source( $contents, $file ) );
            }
        }

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
        $log->error($error);
        die $error if $params{reject_on_error};
    };
    die $fail_msg if $fail_msg;
}

sub get_changed_files {
    my ( $self, $base, $commit ) = @_;
    my $output = capturex( $self->git_path, "diff", "--numstat", "--name-only", "$base..$commit" );
    my @files = grep { /\S/ } split( "\n", $output );
    return @files;
}

sub get_file_contents {
    my ( $self, $file, $commit ) = @_;
    my $contents = capturex( $self->git_path, "show", "$commit:$file" );
    return $contents;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Git::Prereceive - Git pre-receive hook that requires files to be
tidyall'd

=head1 SYNOPSIS

  In .git/hooks/pre-receive:

    #!/usr/bin/perl
    use Code::TidyAll::Git::Prereceive;
    use strict;
    use warnings;
    
    Code::TidyAll::Git::Prereceive->check();

=head1 DESCRIPTION

This module implements a L<Git pre-receive
hook|http://git-scm.com/book/en/Customizing-Git-Git-Hooks> that checks if all
pushed files are tidied and valid according to L<tidyall|tidyall>, and rejects
the push if not.

This is typically used to validate pushes from multiple developers to a shared
repo, possibly on a remote server.

See also L<Code::TidyAll::Git::Precommit|Code::TidyAll::Git::Precommit>, which
operates locally from the current repo.

=head1 METHODS

=over

=item check (key/value params...)

Class method. Check that all files being added or modified in this push are
tidied and valid according to L<tidyall|tidyall>. If not, then the entire push
is rejected and the reason(s) are output to the client. e.g.

    % git push
    2 files did not pass tidyall check
    lib/CHI.pm: *** 'PerlTidy': needs tidying
    lib/CHI/Driver.pm: *** 'PerlCritic': Code before strictures are enabled
      at /tmp/Code-TidyAll-0e6K/Driver.pm line 2
      [TestingAndDebugging::RequireUseStrict]

The configuration file C<tidyall.ini> must be checked into git in the repo root
directory, i.e. next to the .git directory.

Passes mode = "commit" by default; see L<modes|tidyall/MODES>.

Key/value parameters:

=over

=item conf_file

Name of conf file; default is "tidyall.ini".

=item git_path

Path to git to use in commands, e.g. '/usr/bin/git' or '/usr/local/bin/git'. By
default, just uses 'git', which will search the user's PATH.

=item tidyall_class

Subclass to use instead of L<Code::TidyAll|Code::TidyAll>

=item tidyall_options

Hashref of options to pass to the L<Code::TidyAll|Code::TidyAll> constructor

=back

=back

=cut
