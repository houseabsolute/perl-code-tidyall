use strict;
use warnings;
use Path::Tiny qw/ path /;

my $content = path(shift)->slurp;
$content =~ s/forbidden/safe/i;
print $content;
