package Code::TidyAll::Git::Prereceive;

use Code::TidyAll;
use Code::TidyAll::Util qw(dirname realpath tempdir_simple);
use Capture::Tiny qw(capture);
use Digest::SHA1 qw(sha1_hex);
use File::Slurp::Tiny qw(read_file write_file);
use IPC::System::Simple qw(capturex run);
use Moo;
use Try::Tiny;

our $VERSION = '0.25';

# Public
has 'allow_repeated_push' => ( is => 'ro', default => 3 );
has 'conf_name'           => ( is => 'ro' );
has 'extra_conf_files'    => ( is => 'ro', default => sub { [] } );
has 'git_path'            => ( is => 'ro', default => 'git' );
has 'reject_on_error'     => ( is => 'ro' );
has 'tidyall_class'       => ( is => 'ro', default => 'Code::TidyAll' );
has 'tidyall_options'     => ( is => 'ro', default => sub { {} } );

sub check {
    my ( $class, %params ) = @_;

    my $fail_msg;
    try {
        my $self = $class->new(%params);

        my $root_dir = realpath();
        local $ENV{GIT_DIR} = $root_dir;

        my $input = do { local $/; <STDIN> };
        $fail_msg = $self->check_input($input);
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
    die "$fail_msg\n" if $fail_msg;
}

sub check_input {
    my ( $self, $input ) = @_;

    my @lines = split( "\n", $input );
    my ( @results, $tidyall );
    foreach my $line (@lines) {
        chomp($line);
        my ( $base, $commit, $ref ) = split( /\s+/, $line );

        # Create tidyall using configuration found in first commit
        #
        $tidyall ||= $self->create_tidyall($commit);

        my @files = $self->get_changed_files( $base, $commit );
        foreach my $file (@files) {
            my $contents = $self->get_file_contents( $file, $commit );
            if ( $contents =~ /\S/ && $contents =~ /\n/ ) {
                push( @results, $tidyall->process_source( $contents, $file ) );
            }
        }
    }

    my $fail_msg;
    if ( my @error_results = grep { $_->error } @results ) {
        unless ( $self->check_repeated_push($input) ) {
            my $error_count = scalar(@error_results);
            $fail_msg = sprintf(
                "%d file%s did not pass tidyall check",
                $error_count, $error_count > 1 ? "s" : ""
            );
        }
    }
    return $fail_msg;
}

sub create_tidyall {
    my ( $self, $commit ) = @_;

    my $temp_dir = tempdir_simple();
    my @conf_names = $self->conf_name ? ( $self->conf_name ) : Code::TidyAll->default_conf_names;
    my ($conf_file) = grep { $self->get_file_contents( $_, $commit ) } @conf_names
        or die sprintf( "could not find conf file %s", join( " or ", @conf_names ) );
    foreach my $rel_file ( $conf_file, @{ $self->extra_conf_files } ) {
        my $contents = $self->get_file_contents( $rel_file, $commit )
            or die sprintf( "could not find file '%s' in repo root", $rel_file );
        write_file( "$temp_dir/$rel_file", $contents );
    }
    my $tidyall = $self->tidyall_class->new_from_conf_file(
        "$temp_dir/" . $conf_file,
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
    my @files = grep {/\S/} split( "\n", $output );
    return @files;
}

sub get_file_contents {
    my ( $self, $file, $commit ) = @_;
    my ( $contents, $error ) = capture { system( $self->git_path, "show", "$commit:$file" ) };
    return $contents;
}

sub check_repeated_push {
    my ( $self, $input ) = @_;
    if ( defined( my $allow = $self->allow_repeated_push ) ) {
        my $cwd            = dirname( realpath($0) );
        my $last_push_file = "$cwd/.prereceive_lastpush";
        if ( -w $cwd || -w $last_push_file ) {
            my $push_sig = sha1_hex($input);
            if ( -f $last_push_file ) {
                my ( $last_push_sig, $count ) = split( /\s+/, read_file($last_push_file) );
                if ( $last_push_sig eq $push_sig ) {
                    ++$count;
                    print STDERR "*** Identical push seen $count times\n";
                    if ( $count >= $allow ) {
                        print STDERR "*** Allowing push to proceed despite errors\n";
                        unlink($last_push_file);
                        return 1;
                    }
                    write_file( $last_push_file, join( " ", $push_sig, $count ) );
                    return 0;
                }
            }
            write_file( $last_push_file, join( " ", $push_sig, 1 ) );
        }
    }
    return 0;
}

1;

# ABSTRACT: Git pre-receive hook that requires files to betidyall'd

__END__

=pod

=head1 SYNOPSIS

  In .git/hooks/pre-receive:

    #!/usr/bin/perl
    use Code::TidyAll::Git::Prereceive;
    use strict;
    use warnings;

    Code::TidyAll::Git::Prereceive->check();


    # or

    my $input = do { local $/; <STDIN> };

    # Do other things with $input here

    my $hook = Code::TidyAll::Git::Prereceive->new();
    if (my $error = $hook->check_input($input)) {
        die $error;
    }


=head1 DESCRIPTION

This module implements a L<Git pre-receive
hook|http://git-scm.com/book/en/Customizing-Git-Git-Hooks> that checks if all
pushed files are tidied and valid according to L<tidyall>, and rejects the push
if not.

This is typically used to validate pushes from multiple developers to a shared
repo, possibly on a remote server.

See also L<Code::TidyAll::Git::Precommit>, which operates locally.

=head1 METHODS

=over

=item check (key/value params...)

An all-in-one class method. Reads commit info from standard input, then checks
that all files being added or modified in this push are tidied and valid
according to L<tidyall>. If not, then the entire push is rejected and the
reason(s) are output to the client. e.g.

    % git push
    Counting objects: 9, done.
    ...
    remote: [checked] lib/CHI/Util.pm
    remote: Code before strictures are enabled on line 13 [TestingAndDebugging::RequireUseStrict]
    remote:
    remote: 1 file did not pass tidyall check
    To ...
     ! [remote rejected] master -> master (pre-receive hook declined)

The configuration file (C<tidyall.ini> or C<.tidyallrc>) must be checked into
git in the repo root directory, i.e. next to the .git directory.

In an emergency the hook can be bypassed by pushing the exact same set of
commits 3 consecutive times (configurable via L</allow_repeated_push>):

    % git push
    ...
    remote: 1 file did not pass tidyall check

    % git push
    ...
    *** Identical push seen 2 times
    remote: 1 file did not pass tidyall check

    % git push
    ...
    *** Identical push seen 3 times
    *** Allowing push to proceed despite errors

Or you can disable the hook in the repo being pushed to, e.g. by renaming
.git/hooks/pre-receive.

If an unexpected runtime error occurs, it is reported but by default the commit
will be allowed through (see L</reject_on_error>).

Passes mode = "commit" by default; see L<modes|tidyall/MODES>.

Key/value parameters:

=over

=item allow_repeated_push

Number of times a push must be repeated exactly after which it will be let
through regardless of errors. Defaults to 3. Set to 0 or undef to disable this
feature.

=item conf_name

Conf file name to search for instead of the defaults.

=item extra_conf_files

A listref of extra configuration files referred to from the main configuration
file, e.g.

    extra_conf_files => ['perlcriticrc', 'perltidyrc']

These files will be pulled out of the repo alongside the main configuration
file. If you don't list them here then you'll get errors like 'cannot find
perlcriticrc' when the hook runs.

=item git_path

Path to git to use in commands, e.g. '/usr/bin/git' or '/usr/local/bin/git'. By
default, just uses 'git', which will search the user's PATH.

=item reject_on_error

Whether C<check()> should reject the commit when an unexpected runtime error
occurs. By default, the error will be reported but the commit will be allowed.

=item tidyall_class

Subclass to use instead of L<Code::TidyAll>

=item tidyall_options

Hashref of options to pass to the L<Code::TidyAll> constructor. You can use
this to override the default options

    mode  => 'commit',
    quiet => 1,

or pass additional options.

=back

=item new (key/value params...)

Constructor. Takes the same parameters documented in check(), above, and
returns a new object which you can then call L</check_input> on.

=item check_input (input)

Run a check on I<input>, the text block of lines that came from standard input.
You can call this manually before or after you do other processing on the
input. Returns an error string if there was a problem, undef if no problems.

=back

=head1 KNOWN BUGS

This hook will ignore any files with only a single line of content (no
newlines), as an imperfect way of filtering out symlinks.

=cut
