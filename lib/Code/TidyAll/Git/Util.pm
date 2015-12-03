package Code::TidyAll::Git::Util;

use Cwd qw(realpath);
use Code::TidyAll::Util qw(pushd);
use IPC::System::Simple qw(capturex);
use List::MoreUtils qw(uniq);
use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.38';

our @EXPORT_OK = qw(git_uncommitted_files);

sub git_uncommitted_files {
    my ($dir) = @_;

    $dir = realpath($dir);
    my $pushd  = pushd($dir);
    my $output = capturex( "git", "status" );
    my @files  = ( $output =~ /(?:new file|modified):\s+(.*)/g );
    @files = uniq( map {"$dir/$_"} @files );
    return @files;
}

1;
