package Code::TidyAll::Util;

use strict;
use warnings;

use Path::Tiny 0.098 qw(tempdir);

use Exporter qw(import);

our $VERSION = '0.63';

our @EXPORT_OK = qw(tempdir_simple);

sub tempdir_simple {
    my $template = shift || 'Code-TidyAll-XXXX';

    return tempdir(
        { realpath => 1 },
        TEMPLATE => $template,
        CLEANUP  => 1
    );
}

1;
