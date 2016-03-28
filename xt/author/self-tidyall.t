use strict;
use warnings;

use Test::Code::TidyAll;
use Test::More;

plan skip_all => 'This plugin requires Perl 5.10+'
    unless $] >= 5.010;

tidyall_ok();

done_testing();
