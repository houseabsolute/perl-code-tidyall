package Code::TidyAll::Git::Prereceive;
use Code::TidyAll;
use Code::TidyAll::Util qw(realpath tempdir_simple write_file);
use IPC::System::Simple qw(capturex run);
use Moo;
use SVN::Look;
use Try::Tiny;

# Public
has 'conf_file'        => ( is => 'ro', default => sub { "tidyall.ini" } );
has 'extra_conf_files' => ( is => 'ro', default => sub { [] } );
has 'git_path'         => ( is => 'ro', default => sub { 'git' } );
has 'reject_on_error'  => ( is => 'ro' );
has 'tidyall_class'    => ( is => 'ro', default => sub { "Code::TidyAll" } );
has 'tidyall_options'  => ( is => 'ro', default => sub { {} } );

sub check {
    my ( $class, %params ) = @_;

    my $fail_msg;

    try {
        my $self = $class->new(%params);

        my $root_dir = realpath();
        local $ENV{GIT_DIR} = $root_dir;

        my ( @results, $conf_file, $tidyall );
        while ( my $line = <> ) {
            chomp($line);
            my ( $base, $commit, $ref ) = split( /\s+/, $line );
            next unless $ref eq 'refs/heads/master';

            # Create tidyall using configuration found in first commit
            #
            $tidyall ||= $self->create_tidyall($commit);

            my @files = $self->get_changed_files( $base, $commit );
            foreach my $file (@files) {
                my $contents = $self->get_file_contents( $file, $commit );
                push( @results, $tidyall->process_source( $contents, $file ) );
            }
        }

        if ( my @error_results = grep { $_->error } @results ) {
            my $error_count = scalar(@error_results);
            $fail_msg = sprintf( "%d file%s did not pass tidyall check",
                $error_count, $error_count > 1 ? "s" : "" );
        }
    }
    catch {
        my $error = $_;
        if ( $params{reject_on_error} ) {
            die $error;
        }
        else {
            print STDERR "*** Error running pre-receive hook (allowing push to proceed):\n$error";
        }
    };
    die $fail_msg if $fail_msg;
}

sub create_tidyall {
    my ( $self, $commit ) = @_;

    my $temp_dir = tempdir_simple();
    foreach my $rel_file ( $self->conf_file, @{ $self->extra_conf_files } ) {
        my $contents = $self->get_file_contents( $rel_file, $commit )
          or die sprintf( "could not find file '%s' in repo root", $rel_file );
        write_file( "$temp_dir/$rel_file", $contents );
    }
    my $tidyall = $self->tidyall_class->new_from_conf_file(
        "$temp_dir/" . $self->conf_file,
        mode  => 'commit',
        quiet => 1,
        %{ $self->tidyall_options },
        no_cache   => 1,
        no_backups => 1,
        check_only => 1,
    );
    return $tidyall;
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
operates locally.

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

Hashref of options to pass to the L<Code::TidyAll|Code::TidyAll> constructor.
You can use this to override the default options

    mode  => 'commit',
    quiet => 1,

or pass additional options.

=back

=back

=cut
