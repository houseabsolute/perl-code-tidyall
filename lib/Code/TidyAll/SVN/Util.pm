package Code::TidyAll::SVN::Util;

use Cwd qw(realpath);
use IPC::System::Simple qw(capturex);
use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.40';

our @EXPORT_OK = qw(svn_uncommitted_files);

sub svn_uncommitted_files {
    my ($dir) = @_;

    $dir = realpath($dir);
    my $output = capturex( "svn", "status", $dir );
    my @lines = grep {/^[AM]/} split( "\n", $output );
    my (@files) = grep {-f} ( $output =~ m{^[AM]\s+(.*)$}gm );
    return @files;
}

1;
