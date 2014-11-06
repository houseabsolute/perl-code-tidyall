package Test::Code::TidyAll::SVN;

use Capture::Tiny qw(capture_stdout capture_stderr capture);
use Code::TidyAll::SVN::Precommit;
use Code::TidyAll::SVN::Util qw(svn_uncommitted_files);
use Code::TidyAll::Util qw(dirname mkpath realpath tempdir_simple);
use Code::TidyAll;
use File::Slurp::Tiny qw(read_file write_file);
use IPC::System::Simple qw(run);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

my ( $precommit_hook_template, $tidyall_ini_template );

sub test_svn : Tests {
    my ($self) = @_;

    $self->require_executable('svn');

    my $temp_dir = tempdir_simple;
    my $repo_dir = "$temp_dir/repo";
    my $src_dir  = "$temp_dir/src";
    my $work_dir = "$temp_dir/work";
    my $hook_log = "$temp_dir/hook.log";
    my ( $stdout, $stderr );

    my $log_contains = sub {
        my $regex = shift;
        like( read_file($hook_log), $regex );
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
    my $hooks_dir = "$repo_dir/hooks";
    ok( -d $hooks_dir, "$hooks_dir exists" );

    mkpath( $src_dir, 0, 0775 );
    write_file( "$src_dir/foo.txt", "abc" );

    run( sprintf( 'svn -q import %s file://%s/myapp/trunk -m "import"', $src_dir,  $repo_dir ) );
    run( sprintf( 'svn -q checkout file://%s/myapp/trunk %s',           $repo_dir, $work_dir ) );

    is( read_file("$work_dir/foo.txt"), "abc", "checkout and import ok" );
    cmp_deeply( [ svn_uncommitted_files($work_dir) ], [], "no uncommitted files" );

    my $precommit_hook_file = "$hooks_dir/pre-commit";
    my $precommit_hook = sprintf( $precommit_hook_template, realpath("lib"), $hook_log );
    write_file( $precommit_hook_file, $precommit_hook );
    chmod( 0775, $precommit_hook_file );

    write_file( "$work_dir/foo.txt", "abc " );
    mkpath( "$work_dir/bar", 0, 0775 );
    run( sprintf( 'svn add %s/bar', $work_dir ) );
    cmp_deeply( [ svn_uncommitted_files($work_dir) ], [ re("foo.txt") ], "one uncommitted file" );

    $stderr = capture_stderr {
        run( sprintf( 'svn -q commit -m "changed" %s/foo.txt %s/bar', $work_dir, $work_dir ) );
    };
    unlike( $stderr, qr/\S/ );
    $log_contains->(qr|could not find.*upwards from 'myapp/trunk/foo.txt'|);
    $clear_log->();
    $committed->();
    cmp_deeply( [ svn_uncommitted_files($work_dir) ], [], "no uncommitted files" );

    write_file( "$work_dir/tidyall.ini", sprintf($tidyall_ini_template) );
    run( sprintf( 'svn -q add %s/tidyall.ini', $work_dir ) );
    cmp_deeply(
        [ svn_uncommitted_files($work_dir) ],
        [ re("tidyall.ini") ],
        "one uncommitted file"
    );
    run( sprintf( 'svn -q commit -m "added" %s/tidyall.ini', $work_dir ) );

    write_file( "$work_dir/foo.txt", "abc" );
    $stderr =
      capture_stderr { system( sprintf( 'svn -q commit -m "changed" %s/foo.txt', $work_dir ) ) };
    like( $stderr, qr/1 file did not pass tidyall check/ );
    like( $stderr, qr/needs tidying/ );
    $uncommitted->();

    write_file( "$work_dir/foo.txt", "ABC" );
    write_file( "$work_dir/bar.dat", "123" );
    run( sprintf( 'svn -q add %s/bar.dat', $work_dir ) );
    $stderr = capture_stderr {
        system(
            sprintf( 'svn -q commit -m "changed" %s/foo.txt %s/bar.dat', $work_dir, $work_dir ) );
    };
    unlike( $stderr, qr/\S/ );
    $committed->();

    write_file( "$work_dir/foo.txt", "def" );
    $stderr = capture_stderr {
        system( sprintf( 'svn -q commit -m "NO TIDYALL - emergency fix!" %s/foo.txt', $work_dir ) );
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
