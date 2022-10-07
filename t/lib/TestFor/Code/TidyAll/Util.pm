package TestFor::Code::TidyAll::Util;

use Code::TidyAll::Util qw( tempdir_simple );
use Path::Tiny          qw( path );
use Test::Class::Most parent => 'TestHelper::Test::Class';

sub test_tempdir_simple : Tests {
    my $dir;
    {
        my $tempdir = tempdir_simple();
        $dir = path($tempdir);
        ok( -d $tempdir, 'tempdir exists' );
    }
    ok( -d $dir->parent, 'parent exists' );
    ok( !-d $dir,        'tempdir does not exist after it goes out of scope' );
}

1;
