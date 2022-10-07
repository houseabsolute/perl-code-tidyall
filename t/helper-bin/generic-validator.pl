use strict;
use warnings;

use Path::Tiny qw( path );
exit 1 if path(shift)->slurp =~ /forbidden/i;
