package Code::TidyAll::Git::Util;

use Cwd qw(realpath);
use Code::TidyAll::Util qw(pushd);
use IPC::System::Simple qw(capturex);
use List::MoreUtils qw(uniq);
use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.39';

our @EXPORT_OK = qw(git_uncommitted_files);

sub _relevant_files_from_status {
    my ($porcelain) = @_;

    my ($comment, $rest) = split /\0/, $porcelain, 2;

    my @files;

    {
      local $_ = $rest;

      # There can't possibly be more records than nuls plus one, so we use this
      # as an upper bound on passes.
      my $times = tr/\0/\0/;

      for my $i (0 .. $times) {
        last if /\G\Z/gc;

        /\G(..) /g;
        my $mode = $1;

        /\G([^\0]+)\0/g;
        my $name = $1;

        # on renames, parse but throw away the "renamed from" filename
        if ($mode =~ /R/) {
          /\G([^\0]+)\0/g;
        }

        # deletions and renames don't cause tidying
        next unless $mode =~ /[MAC]/;

        push @files, $name;
      }
    }

    return @files;
}

sub git_uncommitted_files {
    my ($dir) = @_;

    $dir = realpath($dir);
    my $pushd  = pushd($dir);
    my $output = capturex( "git", "status", "--porcelain", "-z" );

    my @files = _relevant_files_from_status($output);

    @files = uniq( map {"$dir/$_"} @files );
    return @files;
}

1;
