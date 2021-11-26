use strict;
use warnings;

use Test::Code::TidyAll;
use Test::More;

plan skip_all => q{This is broken because of tidyall's broken UTF-8 handling. This is because we now have a contributor in Git with a UTF-8 character in their name, and this gets mangled during tidying. Oh, the irony.};

plan skip_all => 'This plugin requires Perl 5.10+'
    unless $] >= 5.010;

tidyall_ok( verbose => 1 );

done_testing();
