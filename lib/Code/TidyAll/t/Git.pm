package Code::TidyAll::t::Git;
use Capture::Tiny qw(capture_stdout capture_stderr capture);
use Code::TidyAll::Git::Util qw(git_uncommitted_files);
use Code::TidyAll::Util qw(dirname mkpath pushd read_file realpath tempdir_simple write_file);
use Code::TidyAll;
use IPC::System::Simple qw(run);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

my ( $precommit_hook_template, $tidyall_ini_template );

sub test_git : Tests {
    my ($self) = @_;

    my $temp_dir  = tempdir_simple;
    my $work_dir  = "$temp_dir/work";
    my $hooks_dir = "$work_dir/.git/hooks";
    my ( $stdout, $stderr );

    my $committed = sub {
        $stdout = capture_stdout { system('git status') };
        like( $stdout, qr/nothing to commit/, "committed" );
    };

    my $uncommitted = sub {
        $stdout = capture_stdout { system('git status') };
        unlike( $stdout, qr/nothing to commit/, "uncommitted" );
    };

    run( "git", "init", $work_dir );
    ok( -d $_, "$_ exists" ) for ( $work_dir, $hooks_dir );
    my $pushd = pushd($work_dir);

    write_file( "$work_dir/tidyall.ini", sprintf($tidyall_ini_template) );
    write_file( "$work_dir/.gitignore",  ".tidyall.d" );
    run( "git", "add", "tidyall.ini", ".gitignore" );
    run( "git", "commit", "-m", "added", "tidyall.ini", ".gitignore" );

    write_file( "$work_dir/foo.txt", "abc" );
    cmp_deeply( [ git_uncommitted_files($work_dir) ], [], "no uncommitted files" );

    run( "git", "add", "foo.txt" );
    cmp_deeply( [ git_uncommitted_files($work_dir) ],
        ["$work_dir/foo.txt"], "one uncommitted file" );

    my $precommit_hook_file = "$hooks_dir/pre-commit";
    my $precommit_hook = sprintf( $precommit_hook_template, realpath("lib") );
    write_file( $precommit_hook_file, $precommit_hook );
    chmod( 0775, $precommit_hook_file );

    $stderr = capture_stderr { system( "git", "commit", "-m", "changed", "-a" ) };
    like( $stderr, qr/1 file did not pass tidyall check/ );
    like( $stderr, qr/needs tidying/ );
    $uncommitted->();

    write_file( "$work_dir/foo.txt", "ABC" );
    $stderr = capture_stderr { system( "git", "commit", "-m", "changed", "-a" ) };
    like( $stderr, qr/\[checked\] foo\.txt/ );
    $committed->();
}

$precommit_hook_template = '#!/usr/bin/perl
use lib qw(%s);
use Code::TidyAll::Git::Precommit;
use strict;
use warnings;

Code::TidyAll::Git::Precommit->check(
    tidyall_options => { verbose => 1 }
);
';

$tidyall_ini_template = '
[+Code::TidyAll::Test::Plugin::UpperText]
select = **/*.txt
';

1;
