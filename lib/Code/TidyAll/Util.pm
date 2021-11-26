package Code::TidyAll::Util;

use strict;
use warnings;

use File::Spec;
use Path::Tiny 0.098 qw(tempdir);

use Exporter qw(import);

our $VERSION = '0.81';

our @EXPORT_OK = qw(tempdir_simple);

use constant IS_WIN32 => $^O eq 'MSWin32';

sub tempdir_simple {
    my $template = shift || 'Code-TidyAll-XXXX';

    my %args = (
        TEMPLATE => $template,
        CLEANUP  => 1
    );

    # On Windows the default tmpdir is under C:\Users\<Current User>. If the
    # current user name is long or has spaces, then you get a short name like
    # LONGUS~1. But lots of other code, particularly in the tests, will end up
    # seeing long path names. This makes comparing paths to see if one path is
    # under the tempdir fail, because the long name and short name don't
    # compare as equal.
    if (IS_WIN32) {
        require Win32;
        $args{DIR} = Win32::GetLongPathName( File::Spec->tmpdir );
    }

    return tempdir(
        { realpath => 1 },
        %args,
    );
}

1;

# ABSTRACT: Utility functions for internal use by Code::TidyAll
