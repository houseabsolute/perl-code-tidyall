package Code::TidyAll::Util;

use strict;
use warnings;

use File::Spec;
use Path::Tiny 0.098 qw(tempdir);

use Exporter qw(import);

our $VERSION = '0.64';

our @EXPORT_OK = qw(tempdir_simple);

use constant IS_WIN32 => $^O eq 'MSWin32';

sub tempdir_simple {
    my $template = shift || 'Code-TidyAll-XXXX';

    my %args = (
        TEMPLATE => $template,
        CLEANUP  => 1
    );
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
