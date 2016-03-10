package Code::TidyAll::Git::Util;

use Cwd qw(realpath);
use Code::TidyAll::Util qw(pushd rel2abs);
use IPC::System::Simple qw(capturex);
use List::SomeUtils qw(uniq);
use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.43';

our @EXPORT_OK = qw(git_uncommitted_files);

sub git_uncommitted_files {
    my ($dir) = @_;
    my $pushd = pushd( realpath($dir) );
    return
        map { rel2abs($_) }
        _relevant_files_from_status( capturex(qw( git status --porcelain -z -uno )) );
}

sub _relevant_files_from_status {
    my ($status) = @_;

    return unless $status;

    my @files;
    {
        local $_ = $status;

        # There can't possibly be more records than nuls plus one, so we use this
        # as an upper bound on passes.
        my $times = tr/\0/\0/;

        for my $i ( 0 .. $times ) {
            last if /\G\Z/gc;

            /\G(..) /g;
            my $mode = $1;

            /\G([^\0]+)\0/g;
            my $name = $1;

            # on renames, parse but throw away the "renamed from" filename
            if ( $mode =~ /R/ ) {
                /\G([^\0]+)\0/g;
            }

            # deletions and renames don't cause tidying
            next unless $mode =~ /[MAC]/;

            push @files, $name;
        }
    }

    return @files;
}

1;
