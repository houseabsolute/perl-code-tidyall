package Test::Code::TidyAll::Zglob;

use File::Zglob;
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';
use Code::TidyAll::Util::Zglob qw(zglob_to_regex);

sub test_match : Tests {
    my ( $zglob, $regex );

    $zglob = "**/*.txt";
    $regex = zglob_to_regex($zglob);
    foreach my $path (qw(foo.txt foo/baz.txt foo/bar/baz.txt)) {
        like( $path, $regex, "$path matches $zglob" );
    }
    foreach my $path (qw(foo/bar/baz.tx)) {
        unlike( $path, $regex, "$path does not match $zglob" );
    }

    $zglob = "**/*";
    $regex = zglob_to_regex($zglob);
    foreach my $path (qw(foo foo.txt foo/bar foo/baz.txt)) {
        like( $path, $regex, "$path matches $zglob" );
    }

    $zglob = "foo/**/*.txt";
    $regex = zglob_to_regex($zglob);
    foreach my $path (qw(foo/baz.txt foo/bar/baz.txt foo/bar/baz/blargh.txt)) {
        like( $path, $regex, "$path matches $zglob" );
    }
    foreach my $path (qw(foo.txt foo/bar/baz.tx)) {
        unlike( $path, $regex, "$path does not match $zglob" );
    }
}

1;
