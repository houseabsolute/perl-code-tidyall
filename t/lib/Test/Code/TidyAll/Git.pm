package Test::Code::TidyAll::Git;

use Capture::Tiny qw(capture_stdout capture_stderr capture);
use Code::TidyAll::Git::Util qw(git_uncommitted_files);
use Code::TidyAll::Util qw(dirname mkpath pushd read_file realpath tempdir_simple write_file);
use Code::TidyAll;
use IPC::System::Simple qw(capturex run);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

my ( $precommit_hook_template, $prereceive_hook_template, $tidyall_ini_template );

sub test_git : Tests {
    my ($self) = @_;

    $self->require_executable('git');

    my $temp_dir  = tempdir_simple;
    my $work_dir  = "$temp_dir/work";
    my $hooks_dir = "$work_dir/.git/hooks";
    my $output;

    my $committed = sub {
        like( capturex( 'git', 'status' ), qr/nothing to commit/, "committed" );
    };
    my $uncommitted = sub {
        unlike( capturex( 'git', 'status' ), qr/nothing to commit/, "committed" );
    };

    my $pushed = sub {
        unlike( capturex( 'git', 'status' ), qr/Your branch is ahead/, "pushed" );
    };
    my $unpushed = sub {
        like( capturex( 'git', 'status' ), qr/Your branch is ahead/, "unpushed" );
    };

    # Create the repo
    #
    run( "git", "init", $work_dir );
    ok( -d $_, "$_ exists" ) for ( $work_dir, $hooks_dir );
    my $pushd = pushd($work_dir);

    # Add tidyall.ini and .gitignore
    #
    write_file( "$work_dir/tidyall.ini", sprintf($tidyall_ini_template) );
    write_file( "$work_dir/.gitignore",  ".tidyall.d" );
    run( "git", "add", "tidyall.ini", ".gitignore" );
    run( "git", "commit", "-m", "added", "tidyall.ini", ".gitignore" );

    # Add foo.txt, which needs tidying
    #
    write_file( "$work_dir/foo.txt", "abc\n" );
    cmp_deeply( [ git_uncommitted_files($work_dir) ], [], "no uncommitted files" );

    # git add foo.txt and make sure it is now in uncommitted list
    #
    run( "git", "add", "foo.txt" );
    cmp_deeply( [ git_uncommitted_files($work_dir) ],
        ["$work_dir/foo.txt"], "one uncommitted file" );

    # Add pre-commit hook
    #
    my $precommit_hook_file = "$hooks_dir/pre-commit";
    my $precommit_hook = sprintf( $precommit_hook_template, realpath("lib") );
    write_file( $precommit_hook_file, $precommit_hook );
    chmod( 0775, $precommit_hook_file );

    # Try to commit, make sure we get error
    #
    $output = capture_stderr { system( "git", "commit", "-m", "changed", "-a" ) };
    like( $output, qr/1 file did not pass tidyall check/, "1 file did not pass tidyall check" );
    like( $output, qr/needs tidying/, "needs tidying" );
    $uncommitted->();

    # Fix file and commit successfully
    #
    write_file( "$work_dir/foo.txt", "ABC\n" );
    $output = capture_stderr { run( "git", "commit", "-m", "changed", "-a" ) };
    like( $output, qr/\[checked\] foo\.txt/, "checked foo.txt" );
    $committed->();

    # Create a bare shared repo, then a clone of that
    #
    my $shared_dir = "$temp_dir/shared";
    my $clone_dir  = "$temp_dir/clone";
    run( "git", "clone", "-q", "--bare", $work_dir, $shared_dir );
    run( "git", "clone", "-q", $shared_dir, $clone_dir );
    chdir($clone_dir);
    $committed->();

    # Add prereceive hook to shared repo
    #
    my $prereceive_hook_file = "$shared_dir/hooks/pre-receive";
    my $prereceive_hook = sprintf( $prereceive_hook_template, realpath("lib") );
    write_file( $prereceive_hook_file, $prereceive_hook );
    chmod( 0775, $prereceive_hook_file );

    # Unfix file and commit
    #
    write_file( "$clone_dir/foo.txt", "def\n" );
    run( "git", "commit", "-m", "changed", "-a" );
    $committed->();

    # Try to push, make sure we get error back
    #
    $unpushed->();
    $output = capture_stderr { system( "git", "push" ) };
    like( $output, qr/master -> master/,                  "master -> master" );
    like( $output, qr/1 file did not pass tidyall check/, "1 file did not pass tidyall check" );
    like( $output, qr/needs tidying/,                     "needs tidying" );
    $unpushed->();

    # Fix file and push successfully
    #
    write_file( "$clone_dir/foo.txt", "DEF\n" );
    $output = capture_stderr { run( "git", "commit", "-m", "changed", "-a" ) };
    $committed->();
    $output = capture_stderr { system( "git", "push" ) };
    like( $output, qr/master -> master/, "master -> master" );
    $pushed->();

    # Unfix file and commit
    #
    write_file( "$clone_dir/foo.txt", "def\n" );
    run( "git", "commit", "-m", "changed", "-a" );
    $committed->();

    # Try #1: make sure we get error back
    #
    $unpushed->();
    $output = capture_stderr { system( "git", "push" ) };
    like( $output, qr/needs tidying/, "needs tidying" );
    $unpushed->();

    # Try #2: make sure we get error and repeat notification back
    #
    $unpushed->();
    $output = capture_stderr { system( "git", "push" ) };
    like( $output, qr/needs tidying/, "needs tidying" );
    like( $output, qr/Identical push seen 2 times/, "Identical push seen 2 times" );
    $unpushed->();

}

$precommit_hook_template = '#!' . $^X . "\n" . <<'EOF';
use lib qw(%s);
use Code::TidyAll::Git::Precommit;
use strict;
use warnings;

Code::TidyAll::Git::Precommit->check(
    tidyall_options => { verbose => 1 }
);
EOF

$prereceive_hook_template = '#!' . $^X . "\n" . <<'EOF';
use lib qw(%s);
use Code::TidyAll::Git::Prereceive;
use strict;
use warnings;

Code::TidyAll::Git::Prereceive->check();
EOF

$tidyall_ini_template = <<'EOF';
[+Code::TidyAll::Test::Plugin::UpperText]
select = **/*.txt
EOF

1;
