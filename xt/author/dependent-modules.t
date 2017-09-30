use strict;
use warnings;

use Cwd qw( abs_path );
use Test::More;

BEGIN {
    plan skip_all => 'Must set TIDYALL_TEST_DEPS to true in order to run these tests'
        unless $ENV{TIDYALL_TEST_DEPS};
}

use Test::DependentModules qw( test_all_dependents );

local $ENV{AUTHOR_TESTING}       = 0;
local $ENV{RELEASE_TESTING}      = 0;
local $ENV{PERL_TEST_DM_LOG_DIR} = abs_path('.');

test_all_dependents(
    'Code::TidyAll', {
        # We only care about plugins, not every module that includes tidyall
        # as a developer dep.
        filter => sub { $_[0] =~ /^Code-TidyAll-/ }
    }
);
