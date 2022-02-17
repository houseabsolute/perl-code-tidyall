package Code::TidyAll::SVN::Util;

use strict;
use warnings;

use Cwd qw(realpath);
use IPC::System::Simple qw(capturex);

use Exporter qw(import);

our $VERSION = '0.82';

our @EXPORT_OK = qw(svn_uncommitted_files);

sub svn_uncommitted_files {
    my ($dir) = @_;

    $dir = realpath($dir);
    my $output  = capturex( 'svn', 'status', $dir );
    my @lines   = grep {/^[AM]/} split( "\n", $output );
    my (@files) = grep {-f} ( $output =~ m{^[AM]\s+(.*)$}gm );
    return @files;
}

1;

# ABSTRACT: Utility functions for SVN hooks
