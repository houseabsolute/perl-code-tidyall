package Code::TidyAll::Git::Prereceive;
use Code::TidyAll;
use Code::TidyAll::Util qw(realpath tempdir_simple write_file);
use Capture::Tiny qw(capture);
use IPC::System::Simple qw(capturex run);
use Moo;
use Try::Tiny;

# Public
has 'conf_name'        => ( is => 'ro' );
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

        my ( @results, $tidyall );
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
    die "$fail_msg\n" if $fail_msg;
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
    my @files = grep { /\S/ } split( "\n", $output );
    return @files;
}

sub get_file_contents {
    my ( $self, $file, $commit ) = @_;
    my ( $contents, $error ) = capture { system( $self->git_path, "show", "$commit:$file" ) };
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

Unfortunately there is no easy way to bypass the pre-receive hook in an
emergency.  It must be disabled in the repo being pushed to, e.g. by renaming
.git/hooks/pre-receive.

Passes mode = "commit" by default; see L<modes|tidyall/MODES>.

Key/value parameters:

=over

=item conf_file

Name of conf file; default is C<tidyall.ini>.

=item extra_conf_files

A listref of configuration files referred to from C<tidyall.ini>, e.g.

    extra_conf_files => ['perlcriticrc', 'perltidyrc']

These files will be pulled out of the repo along with C<tidyall.ini>. If you
don't list them here then you'll get errors like 'cannot find perlcriticrc'
when the hook runs.

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
