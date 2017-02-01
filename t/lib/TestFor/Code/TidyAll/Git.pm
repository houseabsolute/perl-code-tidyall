package TestFor::Code::TidyAll::Git;

use Capture::Tiny qw(capture_stdout capture_stderr capture);
use Code::TidyAll::Git::Util qw(git_files_to_commit git_modified_files);
use Code::TidyAll::Util qw(pushd tempdir_simple);
use Code::TidyAll;
use IPC::System::Simple qw(capturex run);
use Path::Tiny qw(path);
use Test::Class::Most parent => 'TestHelper::Test::Class';

my ( $precommit_hook_template, $prereceive_hook_template, $tidyall_ini_template );

sub test_git : Tests {
    my ($self) = @_;

    $self->require_executable('git');

    my $temp_dir  = tempdir_simple;
    my $work_dir  = $temp_dir->child('work');
    my $hooks_dir = $work_dir->child(qw( .git hooks ));
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

    my $lib_dirs = join q{ }, map { path($_)->realpath } qw( lib t/lib );

    # Create the repo
    #
    run( "git", "init", $work_dir );
    ok( -d $_, "$_ exists" ) for ( $work_dir, $hooks_dir );
    my $pushd = pushd($work_dir);

    # Add tidyall.ini and .gitignore
    #
    $work_dir->child('tidyall.ini')->spew( sprintf($tidyall_ini_template) );
    $work_dir->child('.gitignore')->spew('.tidyall.d');
    run( "git", "add", "tidyall.ini", ".gitignore" );
    run( "git", "commit", "-q", "-m", "added", "tidyall.ini", ".gitignore" );

    # Add foo.txt, which needs tidying
    #
    $work_dir->child('foo.txt')->spew("abc\n");
    cmp_deeply( [ git_files_to_commit($work_dir) ], [], "no files to commit" );

    # git add foo.txt and make sure it is now in uncommitted list
    #
    run(qw( git add foo.txt ));
    cmp_deeply(
        [ map { $_->stringify } git_files_to_commit($work_dir) ],
        [ $work_dir->child('foo.txt')->stringify ], "one file to commit"
    );

    # Add pre-commit hook
    #
    my $precommit_hook_file = $hooks_dir->child('pre-commit');
    my $precommit_hook = sprintf( $precommit_hook_template, $lib_dirs );
    $precommit_hook_file->spew($precommit_hook);
    $precommit_hook_file->chmod(0755);

    # Try to commit, make sure we get error
    #
    $output = capture_stderr { system( "git", "commit", "-m", "changed", "-a" ) };
    like( $output, qr/1 file did not pass tidyall check/, "1 file did not pass tidyall check" );
    like( $output, qr/needs tidying/, "needs tidying" );
    $uncommitted->();

    # Fix file and commit successfully
    #
    $work_dir->child('foo.txt')->spew("ABC\n");
    $output = capture_stderr { run( "git", "commit", "-m", "changed", "-a" ) };
    like( $output, qr/\[checked\] foo\.txt/, "checked foo.txt" );
    $committed->();

    $work_dir->child('bar.txt')->spew("ABC");
    run( "git", "add", "bar.txt" );
    run( "git", "commit", "-q", "-m", "bar.txt" );

    $work_dir->child('bar.txt')->spew("def");
    cmp_deeply( [ git_files_to_commit($work_dir) ], [], "no files to commit" );
    cmp_deeply(
        [ map { $_->stringify } git_modified_files($work_dir) ],
        ["$work_dir/bar.txt"],
        "one file was modified"
    );

    # Create a bare shared repo, then a clone of that
    #
    my $shared_dir = $temp_dir->child('shared');
    my $clone_dir  = $temp_dir->child('clone');
    run( "git", "clone", "-q", "--bare", $work_dir, $shared_dir );
    run( "git", "clone", "-q", $shared_dir, $clone_dir );
    chdir($clone_dir);
    $committed->();

    # Add prereceive hook to shared repo
    #
    my $prereceive_hook_file = $shared_dir->child(qw( hooks pre-receive ));
    my $prereceive_hook = sprintf( $prereceive_hook_template, $lib_dirs );
    $prereceive_hook_file->spew($prereceive_hook);
    $prereceive_hook_file->chmod(0775);

    # Unfix file and commit
    #
    $clone_dir->child('foo.txt')->spew("def\n");
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
    $clone_dir->child('foo.txt')->spew("DEF\n");
    $output = capture_stderr { run( "git", "commit", "-m", "changed", "-a" ) };
    $committed->();
    $output = capture_stderr { system( "git", "push" ) };
    like( $output, qr/master -> master/, "master -> master" );
    $pushed->();

    # Unfix file and commit
    #
    $clone_dir->child('foo.txt')->spew("def\n");
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
[+TestHelper::Plugin::UpperText]
select = **/*.txt
EOF

1;
