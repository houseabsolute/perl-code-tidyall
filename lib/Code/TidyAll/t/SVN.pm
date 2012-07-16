package Code::TidyAll::t::SVN;
use Code::TidyAll::Util qw(dirname mkpath read_file realpath tempdir_simple write_file);
use Code::TidyAll;
use Capture::Tiny qw(capture_stdout);
use IPC::System::Simple qw(run);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

my $precommit_hook_template;

sub test_svn_precommit_hook : Tests {
    my ($self) = @_;

    my $temp_dir = tempdir_simple;
    my $repo_dir = "$temp_dir/repo";
    my $src_dir  = "$temp_dir/src";
    my $work_dir = "$temp_dir/work";

    run("svnadmin create $repo_dir");
    my $hooks_dir = "$repo_dir/hooks";
    ok( -d $hooks_dir, "$hooks_dir exists" );

    mkpath( $src_dir, 0, 0775 );
    write_file( "$src_dir/foo.txt", "abc" );

    run( sprintf( 'svn import %s file://%s/myapp/trunk -m "import"', $src_dir,  $repo_dir ) );
    run( sprintf( 'svn checkout -q file://%s/myapp/trunk %s',        $repo_dir, $work_dir ) );

    is( read_file("$work_dir/foo.txt"), "abc", "checkout and import ok" );

    my $precommit_hook_file = "$hooks_dir/pre-commit";
    my $precommit_hook = sprintf( $precommit_hook_template, realpath("lib") );
    write_file( $precommit_hook_file, $precommit_hook );

}

$precommit_hook_template = '#!/usr/bin/perl
use lib qw(%s);
use Code::TidyAll::SVN::Precommit;
use Log::Any::Adapter;
use strict;
use warnings;

Log::Any::Adapter->set( "Dispatch",
    outputs => [ [ "Screen", min_level => "debug", newline => 1 ] ] );
Code::TidyAll::SVN::Precommit->check(
    extra_conf_files => ["perlcriticrc"],
    tidyall_options => { verbose => 1 }
);
';
