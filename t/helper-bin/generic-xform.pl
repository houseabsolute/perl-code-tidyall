use strict;
use warnings;
use Path::Tiny qw/ path /;

my $content = path(shift)->slurp_raw;
printf('%v02X', $content);
