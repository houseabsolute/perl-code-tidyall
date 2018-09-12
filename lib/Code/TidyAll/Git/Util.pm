package Code::TidyAll::Git::Util;

use strict;
use warnings;

use File::pushd qw(pushd);
use IPC::System::Simple qw(capturex);
use List::SomeUtils qw(uniq);
use Path::Tiny qw(path);

use Exporter qw(import);

our $VERSION = '0.72';

our @EXPORT_OK = qw(git_files_to_commit git_modified_files);

sub git_files_to_commit {
    my ($dir) = @_;
    return _relevant_files_from_status( $dir, 1 );
}

sub git_modified_files {
    my ($dir) = @_;
    return _relevant_files_from_status( $dir, 0 );
}

sub _relevant_files_from_status {
    my ( $dir, $index_only ) = @_;

    $dir = path($dir);
    my $pushed = pushd( $dir->absolute );
    my $status = capturex(qw( git status --porcelain -z -uno ));

    return unless $status;

    return map { $dir->child($_) } _parse_status( $status, $index_only );
}

sub _parse_status {
    my ( $status, $index_only ) = @_;

    local $_ = $status;

    # There can't possibly be more records than nuls plus one, so we use this
    # as an upper bound on passes.
    my $times = tr/\0/\0/;

    my @files;

    for my $i ( 0 .. $times ) {
        last if /\G\Z/gc;

        /\G(..) /g;
        my $mode = $1;

        /\G([^\0]+)\0/g;
        my $name = $1;

        # on renames, parse but throw away the "renamed from" filename
        if ( $mode =~ /[CR]/ ) {
            /\G([^\0]+)\0/g;
        }

        # deletions and renames don't cause tidying
        next unless $mode =~ /[MA]/;
        next if $index_only && $mode =~ /^ /;

        push @files, $name;
    }

    return @files;
}

1;

# ABSTRACT: Utilities for the git hook classes
