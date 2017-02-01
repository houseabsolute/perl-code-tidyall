package TestFor::Code::TidyAll::Util;

use IPC::System::Simple qw(capturex);
use Path::Tiny qw(path);
use Test::Class::Most parent => 'TestHelper::Test::Class';

sub test_tempdir_simple : Tests {
    my $dir = path(
        capturex(
            "$^X", "-I",
            "lib", "-MCode::TidyAll::Util",
            "-e",  "print Code::TidyAll::Util::tempdir_simple "
        )
    );
    ok( -d $dir->parent, "parent exists" );
    ok( !-d $dir,        "dir does not exist" );
}

1;
