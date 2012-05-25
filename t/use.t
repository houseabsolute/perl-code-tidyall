#!perl
use Test::More;
use Code::TidyAll;
use Code::TidyAll::Util qw(tempdir_simple);
use Capture::Tiny qw(capture_merged);

my $root_dir = tempdir_simple('Code-TidyAll-XXXX');
my $ct       = Code::TidyAll->new(
    root_dir => $root_dir,
    plugins  => {},
);
is( capture_merged { $ct->tidyall() }, '', 'no output' );

done_testing();
