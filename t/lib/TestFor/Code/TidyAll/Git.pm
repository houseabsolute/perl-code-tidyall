package TestFor::Code::TidyAll::Git;

use Capture::Tiny            qw(capture capture_stderr);
use Code::TidyAll::Git::Util qw(git_files_to_commit git_modified_files);
use Code::TidyAll::Util      qw(tempdir_simple);
use Code::TidyAll;
use File::pushd qw(pushd);
use File::Spec;
use FindBin             qw( $Bin );
use IPC::System::Simple qw(capturex runx);
use Path::Tiny          qw(path);
use Test::Class::Most parent => 'TestHelper::Test::Class';
use Try::Tiny;

use constant IS_WIN32 => $^O eq 'MSWin32';

use constant GIT => qw(git -c init.defaultBranch=master);

my ( $precommit_hook_template, $prereceive_hook_template, $tidyall_ini_template );

$ENV{GIT_AUTHOR_NAME}  = $ENV{GIT_COMMITTER_NAME}  = 'G. Author';
$ENV{GIT_AUTHOR_EMAIL} = $ENV{GIT_COMMITTER_EMAIL} = 'git-author@example.com';

# Ignore local configuration files, which may change the default branch from
# "master" to "main". Not all versions of GIT support GIT_CONFIG_GLOBAL, however,
# so further settings need to be done on the command line.
$ENV{GIT_CONFIG_GLOBAL} = $ENV{GIT_CONFIG_SYSTEM} = File::Spec->devnull;

BEGIN {
    if (IS_WIN32) {
        __PACKAGE__->SKIP_CLASS(
            q{These tests behave oddly on Windows (at least in Azure). I think it has to do with differences in how output is captured and possible also some line ending issues when the test plugins like UpperText are invoked.}
        );
    }
}

sub test_git : Tests {
    my ($self) = @_;

    return unless $self->require_executable('git');

    my ( $temp_dir, $work_dir, $pushd ) = $self->_make_working_dir_and_repo;

    subtest 'add foo.txt', sub {
        $work_dir->child('foo.txt')->spew_raw("abc\n");
        cmp_deeply( [ git_files_to_commit($work_dir) ], [], 'no files to commit' );

        runx( GIT, qw( add foo.txt ));
        cmp_deeply(
            [ map { $_->stringify } git_files_to_commit($work_dir) ],
            [ $work_dir->child('foo.txt')->stringify ], 'one file to commit'
        );
    };

    subtest 'attempt to commit untidy file', sub {
        my $output = capture_stderr { system( GIT, qw( commit -q -m changed -a )) };
        like( $output, qr/1 file did not pass tidyall check/, '1 file did not pass tidyall check' );
        like( $output, qr/needs tidying/,                     'needs tidying' );
        $self->_assert_something_to_commit($work_dir);
    };

    subtest 'successfully commit tidied file', sub {
        $work_dir->child('foo.txt')->spew_raw("ABC\n");
        my $output = capture_stderr { runx( GIT, qw( commit -q -m changed -a )) };
        like( $output, qr/\[checked\] foo\.txt/, 'checked foo.txt' );
        $self->_assert_nothing_to_commit($work_dir);
    };

    subtest 'add another file which is tidied', sub {
        $work_dir->child('bar.txt')->spew_raw('ABC');
        runx( GIT, qw( add bar.txt ));
        runx( GIT, qw( commit -q -m bar.txt ));

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

        runx( GIT, qw( clone -q --bare ), map { _quote_for_win32($_) } $work_dir,   $shared_dir );
        runx( GIT, qw( clone -q ),        map { _quote_for_win32($_) } $shared_dir, $clone_dir );
        chdir($clone_dir);
        $self->_assert_nothing_to_commit($work_dir);
    };

    my $prereceive_hook_file = $shared_dir->child(qw( hooks pre-receive ));
    my $prereceive_hook      = sprintf( $prereceive_hook_template, $self->_lib_dirs );
    $prereceive_hook_file->spew($prereceive_hook);
    $prereceive_hook_file->chmod(0775);

    subtest 'untidy file and attempt to commit it via commit -a', sub {
        $clone_dir->child('foo.txt')->spew_raw("def\n");
        runx( GIT, qw( commit -q -m changed -a ));
        $self->_assert_nothing_to_commit($work_dir);
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'cannot push untidy file', sub {
        my $output = capture_stderr { system( GIT, qw( push )) };
        like( $output, qr/master -> master/,                  'master -> master' );
        like( $output, qr/1 file did not pass tidyall check/, '1 file did not pass tidyall check' );
        like( $output, qr/needs tidying/,                     'needs tidying' );
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'can push tidied file', sub {
        $clone_dir->child('foo.txt')->spew_raw("DEF\n");
        capture_stderr { runx( GIT, qw( commit -q -m changed -a )) };
        $self->_assert_nothing_to_commit($work_dir);
        my $output = capture_stderr { system( GIT, qw( push )) };
        like( $output, qr/master -> master/, 'push succeeded' );
        $self->_assert_nothing_to_push;
    };

    subtest 'untidy file and commit it', sub {
        $clone_dir->child('foo.txt')->spew_raw("def\n");
        runx( GIT, qw( commit -q -m changed -a ));
        $self->_assert_nothing_to_commit($work_dir);
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'cannot push when file is untidy', sub {
        $self->_assert_branch_is_ahead_of_origin;
        my $output = capture_stderr { system(GIT, qw( push )) };
        like( $output, qr/needs tidying/, 'needs tidying' );
        $self->_assert_branch_is_ahead_of_origin;
    };

    subtest 'cannot push when file is untidy (2nd try)', sub {
        $self->_assert_branch_is_ahead_of_origin;
        my $output = capture_stderr { system(GIT, qw( push )) };
        like( $output, qr/needs tidying/,               'needs tidying' );
        like( $output, qr/Identical push seen 2 times/, 'Identical push seen 2 times' );
        $self->_assert_branch_is_ahead_of_origin;
    };
}

sub test_copied_status : Tests {
    my ($self) = @_;

    return unless $self->require_executable('git');

    my ( $temp_dir, $work_dir, $pushd ) = $self->_make_working_dir_and_repo;

    my $foo_file = $work_dir->child('foo.txt');

    # If the file isn't long enough the new file doesn't end up with the
    # "copied" status.
    $foo_file->spew_raw( "ABC\n" x 500 );

    runx( GIT, qw( add foo.txt ));
    runx( GIT, qw( commit -m foo ));

    my $bar_file = $work_dir->child('bar.txt');
    $bar_file->spew_raw( "ABC\n" x 500 );
    $foo_file->spew_raw(q{});

    runx( GIT, qw( add foo.txt bar.txt ));
    my $output = capture_stderr { runx( GIT, qw( commit -m bar )) };
    unlike(
        $output,
        qr/uninitialized value/i,
        'no warnings from Code::TidyAll::Git::Util module'
    );
}

sub test_precommit_stash_issues : Tests {
    my ($self) = @_;

    return unless $self->require_executable('git');

    my ( $temp_dir, $work_dir, $pushd ) = $self->_make_working_dir_and_repo;

    my $foo_file = $work_dir->child('foo.txt');
    $foo_file->spew_raw("ABC\n");

    my $bar_file = $work_dir->child('bar.txt');
    $bar_file->spew_raw("DEF\n");

    subtest 'commit two tidy files', sub {
        $self->_assert_something_to_commit($work_dir);
        runx( GIT, qw( add foo.txt bar.txt ));
        my $output = capture_stderr( sub { runx( GIT, qw( commit -q -m two )) } );
        like( $output, qr/\Q[checked] foo.txt/, 'tidyall checked foo.txt' );
        like( $output, qr/\Q[checked] bar.txt/, 'tidyall checked bar.txt' );
        $self->_assert_nothing_to_commit($work_dir);
    };

    $foo_file->spew_raw("abc\n");
    $bar_file->spew_raw("abc\n");

    subtest 'cannot commit untidy files', sub {
        $self->_assert_something_to_commit($work_dir);
        my $output = capture_stderr( sub { system(GIT, qw( commit -q -a -m untidy )) } );
        like(
            $output,
            qr/2 files did not pass tidyall check/,
            'commit failed because 2 files are untidy'
        );
        $self->_assert_something_to_commit($work_dir);
    };

    $foo_file->spew_raw("ABC\n");

    my $baz_file = $work_dir->child('baz.txt');
    $baz_file->spew_raw("ABC\n");

    subtest 'commit one valid file and working directory is left intact', sub {
        runx( GIT, qw( add foo.txt ));
        my ( $stdout, $stderr ) = capture( sub { system(GIT, qw( commit -q -m foo )) } );
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

        my $status = capturex(GIT, qw( status --porcelain -unormal ));
        like(
            $status,
            qr/^\?\?\s+baz.txt/m,
            'baz.txt is still untracked in working directory'
        );
    };

    $foo_file->spew_raw("abc\n");
    subtest 'commit one invalid file and working directory is left intact', sub {
        runx( GIT, qw( add foo.txt ));
        my ( undef, $stderr ) = capture( sub { system(GIT, qw( commit -q -m foo )) } );
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

        my $status = capturex(GIT, qw( status --porcelain -unormal ));
        like(
            $status,
            qr/^\?\?\s+baz.txt/m,
            'baz.txt is still untracked in working directory'
        );
    };

    runx( GIT, qw( clean -q -dxf ));

    # We need to add to the stash so we can make sure that it's not popped
    # incorrectly later.
    $foo_file->spew_raw("abC\n");
    runx( GIT, qw( stash -q ));

    subtest 'precommit hook does not pop when it did not stash', sub {
        $foo_file->spew_raw("ABCD\n");
        runx( GIT, qw( commit -q -a -m changed ));

        # The bug we're fixing is that this commit would always pop the stash,
        # even though the Precommit hook's call to "git stash" hadn't _added_
        # to the stash. This meant we'd end up potentially popping some random
        # thing off the stash, making a huge mess.
        my $e;
        try { runx( GIT, qw( commit -q --amend -m amended )) }
        catch { $e = $_ };
        is(
            $e,
            undef,
            'no bogus pop amending a commit when the stash has old content'
        );
    };
}

# See https://github.com/houseabsolute/perl-code-tidyall/issues/100 for the
# bug we're testing.
sub test_precommit_no_stash_merge : Tests {
    my ($self) = @_;

    return unless $self->require_executable('git');

    my ( $temp_dir, $work_dir, $pushd ) = $self->_make_working_dir_and_repo;

    $work_dir->child('file1.txt')->spew("A\nB\n");
    $work_dir->child('file2.txt')->spew("A\nB\n");
    runx( GIT, qw( add file1.txt file2.txt ));
    runx( GIT, qw( commit -m ), 'Add files in master' );

    $work_dir->child('file1.txt')->append("C\n");
    $work_dir->child('file2.txt')->append("C\n");
    runx( GIT, qw( commit -a -m ), 'Update files in master' );

    runx( GIT, qw( checkout -b my-branch ));
    runx( GIT, qw( reset --hard HEAD~1 ));

    $work_dir->child('file1.txt')->append("D\n");
    $work_dir->child('file2.txt')->append("C\n");
    runx( GIT, qw( add file1.txt file2.txt ));
    runx( GIT, qw( commit  -m ), 'Update files in my-branch' );

    # This will exit with 1 because of the conflict.
    runx( [1], GIT, qw( merge master ) );

    like(
        $work_dir->child(qw( .git MERGE_MSG ))->slurp,
        qr/Conflicts:.+file1\.txt/s,
        'merge produced a conflict with file.txt'
    );

    $work_dir->child('file1.txt')->spew("A\nB\nD\n");

    # We need a change that will be stashed to trigger the bug.
    $work_dir->child('file2.txt')->append("E\n");
    runx( GIT, qw( add file1.txt ));
    runx( GIT, qw( commit -m ), 'Add file1.txt in my-branch for real' );
    my $output = capturex(GIT, qw( log -n 1 ));
    like( $output, qr/Merge: [0-9a-f]+ [0-9a-f]+/, 'last commit was a merge commit' );
}

sub _make_working_dir_and_repo {
    my $self = shift;

    my $temp_dir  = tempdir_simple;
    my $work_dir  = $temp_dir->child('work');
    my $hooks_dir = $work_dir->child(qw( .git hooks ));

    runx( GIT, qw( init -q ), _quote_for_win32($work_dir) );

    # This dir doesn't exist unless there's a git dir template that includes
    # the hooks subdir.
    $hooks_dir->mkpath( 0, 0755 );
    ok( -d $_, "$_ exists" ) for ( $work_dir, $hooks_dir );

    my $pushd = pushd($work_dir);

    $work_dir->child('tidyall.ini')->spew($tidyall_ini_template);
    $work_dir->child('.gitignore')->spew('.tidyall.d');
    runx( GIT, qw( add tidyall.ini .gitignore ));
    runx( GIT, qw( commit -q -m added tidyall.ini .gitignore ));

    my $precommit_hook_file = $hooks_dir->child('pre-commit');
    my $precommit_hook      = sprintf( $precommit_hook_template, $self->_lib_dirs );
    $precommit_hook_file->spew($precommit_hook);
    $precommit_hook_file->chmod(0755);

    return ( $temp_dir, $work_dir, $pushd );
}

sub _quote_for_win32 {

    # The docs for IPC::System::Simple lie about how it works on Windows. On
    # Windows it _always_ invokes a shell, so we need to quote a path with
    # spaces.
    return $_[0] unless IS_WIN32 && $_[0] =~ / /;
    return qq{"$_[0]"};
}

sub _lib_dirs {
    my %dirs = map { $_ => 1 } map { path($Bin)->parent->child($_) } qw( lib t/lib );
    if ( $ENV{PERL5LIB} ) {
        my $sep = $^O eq 'MSWin32' ? q{;} : q{:};
        $dirs{$_} = 1 for split /\Q$sep/, $ENV{PERL5LIB};
    }
    return join q{ }, sort keys %dirs;
}

sub _assert_nothing_to_commit {
    shift;
    my @files = git_files_to_commit(shift);
    is( scalar @files, 0, 'there are no files to commit' )
        or diag("@files");
}

sub _assert_something_to_commit {
    shift;
    my @files = git_files_to_commit(shift);
    cmp_ok( scalar @files, '>=', 0, 'there are files to commit' );
}

sub _assert_nothing_to_push {
    unlike(
        capturex( GIT, 'status' ),
        qr/Your branch is ahead/,
        'branch is up to date with origin'
    );
}

sub _assert_branch_is_ahead_of_origin {
    like( capturex( GIT, 'status' ), qr/Your branch is ahead/, 'branch is ahead of origin' );
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

if (IS_WIN32) {
    for my $t ( $precommit_hook_template, $prereceive_hook_template ) {
        ( my $perl = $^X ) =~ s{\\}{/}g;
        $t = qq{#!/bin/sh\n$perl -e '$t'};
    }
}

$tidyall_ini_template = <<'EOF';
[+TestHelper::Plugin::UpperText]
select = **/*.txt
EOF

1;
