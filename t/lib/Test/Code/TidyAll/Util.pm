package Test::Code::TidyAll::Util;

use Code::TidyAll::Util qw(dirname tempdir_simple);
use IPC::System::Simple qw(capturex);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

sub test_tempdir_simple : Tests {
    my $dir = capturex(
        "$^X", "-I",
        "lib", "-MCode::TidyAll::Util",
        "-e",  "print Code::TidyAll::Util::tempdir_simple "
    );
    ok( -d dirname($dir), "parent exists" );
    ok( !-d $dir,         "dir does not exist" );
}

1;
