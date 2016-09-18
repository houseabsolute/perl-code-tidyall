package Test::Code::TidyAll::SVN;

use Capture::Tiny qw(capture_stdout capture_stderr capture);
use Code::TidyAll::SVN::Precommit;
use Code::TidyAll::SVN::Util qw(svn_uncommitted_files);
use Code::TidyAll::Util qw(tempdir_simple);
use Code::TidyAll;
use IPC::System::Simple qw(run);
use Path::Tiny qw(path);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

my ( $precommit_hook_template, $tidyall_ini_template );

sub test_svn : Tests {
    my ($self) = @_;

    $self->require_executable('svn');

    my $temp_dir = tempdir_simple();
    my $repo_dir = $temp_dir->child('repo');
    my $src_dir  = $temp_dir->child('src');
    my $work_dir = $temp_dir->child('work');
    my $hook_log = $temp_dir->child('hook.log');
    my ( $stdout, $stderr );

    my $log_contains = sub {
        my $regex = shift;
        like( $hook_log->slurp, $regex );
    };

    my $clear_log = sub {
        run("cat /dev/null > $hook_log");
    };

    my $committed = sub {
        $stdout = capture_stdout { system( sprintf( 'svn status %s', $work_dir ) ) };
        unlike( $stdout, qr/\S/, "committed" );
    };

    my $uncommitted = sub {
        $stdout = capture_stdout { system( sprintf( 'svn status %s', $work_dir ) ) };
        like( $stdout, qr/^M/, "uncommitted" );
    };

    run("svnadmin create $repo_dir");
    my $hooks_dir = $repo_dir->child('hooks');
    ok( $hooks_dir->is_dir, "$hooks_dir exists" );

    $src_dir->mkpath(0775);
    $src_dir->child('foo.txt')->spew("abc");

    run( sprintf( 'svn -q import %s file://%s/myapp/trunk -m "import"', $src_dir,  $repo_dir ) );
    run( sprintf( 'svn -q checkout file://%s/myapp/trunk %s',           $repo_dir, $work_dir ) );

    my $foo_txt = $work_dir->child('foo.txt');
    is( $foo_txt->slurp, "abc", "checkout and import ok" );
    cmp_deeply( [ svn_uncommitted_files($work_dir) ], [], "no uncommitted files" );

    my $precommit_hook_file = $hooks_dir->child('pre-commit');
    my $precommit_hook = sprintf( $precommit_hook_template, path('lib')->realpath, $hook_log );
    $precommit_hook_file->spew($precommit_hook);
    $precommit_hook_file->chmod(0755);

    my $bar_dir = $work_dir->child('bar');
    $bar_dir->mkpath( { mode => 0755 } );
    $bar_dir->child('foo.txt')->spew("abc ");

    run( sprintf( 'svn -q add %s', $bar_dir ) );
    cmp_deeply( [ svn_uncommitted_files($work_dir) ], [ re("foo.txt") ], "one uncommitted file" );

    $stderr = capture_stderr {
        run( sprintf( 'svn -q commit -m "changed" %s %s', $foo_txt, $bar_dir ) );
    };
    unlike( $stderr, qr/\S/ );
    $log_contains->(qr|could not find.*upwards from 'myapp/trunk/foo.txt'|);
    $clear_log->();
    $committed->();
    cmp_deeply( [ svn_uncommitted_files($work_dir) ], [], "no uncommitted files" );

    my $tidyall_ini = $work_dir->child('tidyall.ini');
    $tidyall_ini->spew($tidyall_ini_template);
    run( sprintf( 'svn -q add %s', $tidyall_ini ) );
    cmp_deeply(
        [ svn_uncommitted_files($work_dir) ],
        [ re("tidyall.ini") ],
        "one uncommitted file"
    );
    run( sprintf( 'svn -q commit -m "added" %s', $tidyall_ini ) );

    $foo_txt->spew("abc");
    $stderr
        = capture_stderr { system( sprintf( 'svn -q commit -m "changed" %s', $foo_txt ) ) };
    like( $stderr, qr/1 file did not pass tidyall check/ );
    like( $stderr, qr/needs tidying/ );
    $uncommitted->();

    $foo_txt->spew("ABC");
    my $bar_dat = $work_dir->child('bar.dat');
    $bar_dat->spew('123');
    run( sprintf( 'svn -q add %s', $bar_dat ) );
    $stderr = capture_stderr {
        system( sprintf( 'svn -q commit -m "changed" %s %s', $foo_txt, $bar_dat ) );
    };
    unlike( $stderr, qr/\S/ );
    $committed->();

    $foo_txt->spew('def');
    $stderr = capture_stderr {
        system( sprintf( 'svn -q commit -m "NO TIDYALL - emergency fix!" %s', $foo_txt ) );
    };
    unlike( $stderr, qr/\S/ );
    $committed->();
}

$precommit_hook_template = '#!' . $^X . "\n" . <<'EOF';
use lib qw(%s);
use Code::TidyAll::SVN::Precommit;
use Log::Any::Adapter (File => "%s");
use strict;
use warnings;

Code::TidyAll::SVN::Precommit->check(
    extra_conf_files => ["perlcriticrc"],
    tidyall_options => { verbose => 1 }
);
EOF

$tidyall_ini_template = <<'EOF';
[+Code::TidyAll::Test::Plugin::UpperText]
select = **/*.txt
EOF
