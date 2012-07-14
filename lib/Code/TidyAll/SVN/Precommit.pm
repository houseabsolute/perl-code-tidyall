package Code::TidyAll::SVN::Precommit;
use Capture::Tiny qw(capture_stdout capture_stderr);
use Code::TidyAll;
use Code::TidyAll::Util qw(dirname mkpath tempdir_simple write_file);
use Log::Any qw($log);
use Moo;
use SVN::Look;
use Try::Tiny;
use strict;
use warnings;

# Public
has 'conf_file'        => ( is => 'ro', default => sub { "tidyall.ini" } );
has 'extra_conf_files' => ( is => 'ro', default => sub { [] } );
has 'repos'            => ( is => 'ro', default => sub { $ARGV[0] } );
has 'tidyall_class'    => ( is => 'ro', default => sub { 'Code::TidyAll' } );
has 'tidyall_options'  => ( is => 'ro', default => sub { {} } );
has 'txn'              => ( is => 'ro', default => sub { $ARGV[1] } );

# Private
has 'cat_file_cache' => ( init_arg => undef, is => 'ro', default => sub { {} } );
has 'revlook'        => ( init_arg => undef, is => 'lazy' );

sub _build_revlook {
    my $self = shift;
    return SVN::Look->new( $self->repos, '-t' => $self->txn );
}

sub check {
    my $class = shift;
    $class->_check(@_);
}

sub _check {
    my ( $class, %params ) = @_;
    my $self = $class->new(%params);

    my @files = ( $self->revlook->added(), $self->revlook->updated() );
    msg("----------------------------");
    msg(
        "%s [%s] repos = %s; txn = %s",
        scalar(localtime), $$, scalar( getpwuid($<) ),
        $self->repos, $self->txn
    );
    msg( "looking at files: %s", join( ", ", @files ) );

    my %root_files;
    foreach my $file (@files) {
        if ( my $root = $self->find_root_for_file($file) ) {
            my $rel_file = substr( $file, length($root) + 1 );
            $root_files{$root}->{$rel_file}++;
        }
        else {
            msg( "** could not find '%s' upwards from '%s'", $self->conf_file, $file );
        }
    }

    my @results;
    while ( my ( $root, $file_map ) = each(%root_files) ) {
        my $tempdir = tempdir_simple();
        my @files   = keys(%$file_map);
        foreach my $rel_file ( $self->conf_file, @{ $self->extra_conf_files }, @files ) {

            # TODO: what if cat fails
            my $contents  = $self->cat_file("$root/$rel_file");
            my $full_path = "$tempdir/$rel_file";
            mkpath( dirname($full_path), 0, 0775 );
            write_file( $full_path, $contents );
        }
        my $tidyall = $self->tidyall_class->new(
            conf_file  => join( "/", $tempdir, $self->conf_file ),
            no_cache   => 1,
            check_only => 1,
            %{ $self->tidyall_options },
        );
        my $stdout = capture_stdout {
            push( @results, $tidyall->process_files( map { "$tempdir/$_" } @files ) );
        };
        if ($stdout) {
            chomp($stdout);
            msg( "%s", $stdout );
        }
    }

    if ( my $error_count = grep { $_->error } @results ) {
        die sprintf( "%d file%s did not pass tidyall check\n",
            $error_count, $error_count > 1 ? "s" : "" );
    }

    die "ok!";
}

sub find_root_for_file {
    my ( $self, $file ) = @_;

    my $conf_file  = $self->conf_file;
    my $search_dir = dirname($file);
    $search_dir =~ s{/+$}{};
    my $cnt = 0;
    while (1) {
        if ( $self->cat_file("$search_dir/$conf_file") ) {
            return $search_dir;
        }
        elsif ( $search_dir eq '/' || $search_dir eq '' ) {
            return undef;
        }
        else {
            $search_dir = dirname($search_dir);
        }
        die "inf loop!" if ++$cnt > 100;
    }
}

sub cat_file {
    my ( $self, $file ) = @_;
    my $contents;
    if ( exists( $self->cat_file_cache->{$file} ) ) {
        $contents = $self->cat_file_cache->{$file};
    }
    else {
        try {
            capture_stderr { $contents = $self->revlook->cat($file) };
        }
        catch {
            $contents = '';
        };
        $self->cat_file_cache->{$file} = $contents;
    }
    return $contents;
}

sub msg {
    my ( $fmt, @params ) = @_;

    $log->infof( $fmt, @params );
}

1;
