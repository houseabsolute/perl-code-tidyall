package TestFor::Code::TidyAll::Git;

use Capture::Tiny qw(capture capture_stderr);
use Code::TidyAll::Git::Util qw(git_files_to_commit git_modified_files);
use Code::TidyAll::Util qw(pushd tempdir_simple);
use Code::TidyAll;
use IPC::System::Simple qw(capturex runx);
use Path::Tiny qw(cwd path);
use Test::Class::Most parent => 'TestHelper::Test::Class';
use Try::Tiny;

my ( $precommit_hook_template, $prereceive_hook_template, $tidyall_ini_template );

my $Cwd = cwd()->realpath;

sub test_git : Tests {
    my ($self) = @_;

    my ( $temp_dir, $work_dir, $pushd ) = $self->_make_working_dir_and_repo;

    subtest 'add foo.txt', sub {
        $work_dir->child('foo.txt')->spew("abc\n");
        cmp_deeply( [ git_files_to_commit($work_dir) ], [], 'no files to commit' );

        runx(qw( git add foo.txt ));
        cmp_deeply(
            [ map { $_->stringify } git_files_to_commit($work_dir) ],
            [ $work_dir->child('foo.txt')->stringify ], 'one file to commit'
        );
    };

    subtest 'attempt to commit untidy file', sub {
        my $output = capture_stderr { system(qw( git commit -q -m changed -a )) };
        like( $output, qr/1 file did not pass tidyall check/, '1 file did not pass tidyall check' );
        like( $output, qr/needs tidying/, 'needs tidying' );
        $self->_assert_something_to_commit;
    };

    subtest 'successfully commit tidied file', sub {
        $work_dir->child('foo.txt')->spew("ABC\n");
        my $output = capture_stderr { runx(qw( git commit -q -m changed -a )) };
        like( $output, qr/\[checked\] foo\.txt/, 'checked foo.txt' );
        $self->_assert_nothing_to_commit;
    };

    subtest 'add another file which is tidied', sub {
        $work_dir->child('bar.txt')->spew('ABC');
        runx(qw( git add bar.txt ));
        runx(qw( git commit -q -m bar.txt ));

        $work_dir->child('bar.txt')->spew('def');
        cmp_deeply( [ git_files_to_commit($work_dir) ], [], 'no files to commit' );
        cmp_deeply(
            [ map { $_->stringify } git_modified_files($work_dir) ],
            ["$work_dir/bar.txt"],
            'one file was modified'
        );
    };

    my ( $shared_dir, $clone_dir );
    subtest 'create bare repo and clone it', sub {
        $shared_dir = $temp_dir->child('shared');
        $clone_dir  = $temp_dir->child('clone');
        runx( qw( git clone -q --bare ), $work_dir,   $shared_dir );
        runx( qw( git clone -q ),        $shared_dir, $clone_dir );
        chdir($clone_dir);
        $self->_assert_nothing_to_commit;
    };

    my $prereceive_hook_file = $shared_dir->child(qw( hooks pre-receive ));
    my $prereceive_hook = sprintf( $prereceive_hook_template, $self->_lib_dirs );
    $prereceive_hook_file->spew($prereceive_hook);
    $prereceive_hook_file->chmod(0775);

    subtest 'untidy file and attempt to commit it via commit -a', sub {
        $clone_dir->child('foo.txt')->spew("def\n");
        runx(qw( git commit -q -m changed -a ));
        $self->_assert_nothing_to_commit;
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'cannot push untidy file', sub {
        my $output = capture_stderr { system(qw( git push )) };
        like( $output, qr/master -> master/,                  'master -> master' );
        like( $output, qr/1 file did not pass tidyall check/, '1 file did not pass tidyall check' );
        like( $output, qr/needs tidying/,                     'needs tidying' );
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'can push tidied file', sub {
        $clone_dir->child('foo.txt')->spew("DEF\n");
        capture_stderr { runx(qw( git commit -q -m changed -a )) };
        $self->_assert_nothing_to_commit;
        my $output = capture_stderr { system(qw( git push )) };
        like( $output, qr/master -> master/, 'push succeeded' );
        $self->_assert_nothing_to_push;
    };

    subtest 'untidy file and commit it', sub {
        $clone_dir->child('foo.txt')->spew("def\n");
        runx(qw( git commit -q -m changed -a ));
        $self->_assert_nothing_to_commit;
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'cannot push when file is untidy', sub {
        $self->_assert_branch_is_ahead_of_origin;
        my $output = capture_stderr { system(qw( git push )) };
        like( $output, qr/needs tidying/, 'needs tidying' );
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'cannot push when file is untidy (2nd try)', sub {
        $self->_assert_branch_is_ahead_of_origin;
        my $output = capture_stderr { system(qw( git push )) };
        like( $output, qr/needs tidying/, 'needs tidying' );
        like( $output, qr/Identical push seen 2 times/, 'Identical push seen 2 times' );
        $self->_assert_branch_is_ahead_of_origin;
    };
}

sub test_precommit_stash_issues : Tests {
    my ($self) = @_;

    my ( $temp_dir, $work_dir, $pushd ) = $self->_make_working_dir_and_repo;

    my $foo_file = $work_dir->child('foo.txt');
    $foo_file->spew("ABC\n");

    my $bar_file = $work_dir->child('bar.txt');
    $bar_file->spew("DEF\n");

    subtest 'commit two tidy files', sub {
        $self->_assert_something_to_commit;
        runx(qw( git add foo.txt bar.txt ));
        my $output = capture_stderr( sub { runx(qw( git commit -q -m two )) } );
        like( $output, qr/\Q[checked] foo.txt/, 'tidyall checked foo.txt' );
        like( $output, qr/\Q[checked] bar.txt/, 'tidyall checked bar.txt' );
        $self->_assert_nothing_to_commit;
    };

    $foo_file->spew("abc\n");
    $bar_file->spew("abc\n");

    subtest 'cannot commit untidy files', sub {
        $self->_assert_something_to_commit;
        my $output = capture_stderr( sub { system(qw( git commit -q -a -m untidy )) } );
        like(
            $output,
            qr/2 files did not pass tidyall check/,
            'commit failed because 2 files are untidy'
        );
        $self->_assert_something_to_commit;
    };

    $foo_file->spew("ABC\n");

    my $baz_file = $work_dir->child('baz.txt');
    $baz_file->spew("ABC\n");

    subtest 'commit one valid file and working directory is left intact', sub {
        runx(qw( git add foo.txt ));
        my ( $stdout, $stderr ) = capture( sub { system(qw( git commit -q -m foo )) } );
        like(
            $stdout,
            qr/modified:\s+bar\.txt/,
            'commit shows bar.txt as still modified'
        );
        is_deeply( [ git_files_to_commit($work_dir) ], [], 'no files to commit' );
        is_deeply(
            [ git_modified_files($work_dir) ],
            [$bar_file],
            'bar.txt is still modified in working directory'
        );

        my $status = capturex(qw( git status --porcelain -unormal ));
        like(
            $status,
            qr/^\?\?\s+baz.txt/m,
            'baz.txt is still untracked in working directory'
        );
    };

    $foo_file->spew("abc\n");
    subtest 'commit one invalid file and working directory is left intact', sub {
        runx(qw( git add foo.txt ));
        my ( undef, $stderr ) = capture( sub { system(qw( git commit -q -m foo )) } );
        like(
            $stderr,
            qr/needs tidying/,
            'commit fails because file is not tidied'
        );
        is_deeply(
            [ git_files_to_commit($work_dir) ],
            [$foo_file],
            'foo.txt is still in the index'
        );
        is_deeply(
            [ git_modified_files($work_dir) ],
            [ $bar_file, $foo_file ],
            'bar.txt is still modified in working directory'
        );

        my $status = capturex(qw( git status --porcelain -unormal ));
        like(
            $status,
            qr/^\?\?\s+baz.txt/m,
            'baz.txt is still untracked in working directory'
        );
    };

    runx(qw( git clean -q -dxf ));

    # We need to add to the stash so we can make sure that it's not popped
    # incorrectly later.
    $foo_file->spew("abC\n");
    runx(qw( git stash -q ));

    subtest 'precommit hook does not pop when it did not stash', sub {
        $foo_file->spew("ABCD\n");
        runx(qw( git commit -q -a -m changed ));

        # The bug we're fixing is that this commit would always pop the stash,
        # even though the Precommit hook's call to "git stash" hadn't _added_
        # to the stash. This meant we'd end up potentially popping some random
        # thing off the stash, making a huge mess.
        my $e;
        try { runx(qw( git commit -q --amend -m amended )) }
        catch { $e = $_ };
        is(
            $e,
            undef,
            'no bogus pop amending a commit when the stash has old content'
        );
    };
}

sub _make_working_dir_and_repo {
    my $self = shift;

    $self->require_executable('git');

    my $temp_dir  = tempdir_simple;
    my $work_dir  = $temp_dir->child('work');
    my $hooks_dir = $work_dir->child(qw( .git hooks ));

    runx( qw( git init -q ), $work_dir );
    ok( -d $_, "$_ exists" ) for ( $work_dir, $hooks_dir );

    my $pushd = pushd($work_dir);

    $work_dir->child('tidyall.ini')->spew( sprintf($tidyall_ini_template) );
    $work_dir->child('.gitignore')->spew('.tidyall.d');
    runx(qw( git add tidyall.ini .gitignore ));
    runx(qw( git commit -q -m added tidyall.ini .gitignore ));

    my $precommit_hook_file = $hooks_dir->child('pre-commit');
    my $precommit_hook = sprintf( $precommit_hook_template, $self->_lib_dirs );
    $precommit_hook_file->spew($precommit_hook);
    $precommit_hook_file->chmod(0755);

    return ( $temp_dir, $work_dir, $pushd );
}

sub _lib_dirs {
    join q{ }, map { $Cwd->child($_) } qw( lib t/lib );
}

sub _assert_nothing_to_commit {
    like( capturex( 'git', 'status' ), qr/nothing to commit/, 'nothing to commit' );
}

sub _assert_something_to_commit {
    unlike( capturex( 'git', 'status' ), qr/nothing to commit/, 'something to commit' );
}

sub _assert_nothing_to_push {
    unlike(
        capturex( 'git', 'status' ),
        qr/Your branch is ahead/,
        'branch is up to date with origin'
    );
}

sub _assert_branch_is_ahead_of_origin {
    like( capturex( 'git', 'status' ), qr/Your branch is ahead/, 'branch is ahead of origin' );
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
