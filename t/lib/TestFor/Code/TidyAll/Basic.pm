package TestFor::Code::TidyAll::Basic;

use Capture::Tiny qw(capture capture_stdout capture_merged);
use Code::TidyAll::CacheModel::Shared;
use Code::TidyAll::Util qw(pushd tempdir_simple);
use Code::TidyAll;
use File::Find qw(find);
use IPC::Run3 qw( run3 );
use Path::Tiny qw(cwd path);

use Test::Class::Most parent => 'TestHelper::Test::Class';

sub test_plugin {"+TestHelper::Plugin::$_[0]"}
my %UpperText
    = ( test_plugin('UpperText') => { select => '**/*.txt', ignore => 'plugin_ignore/*' } );
my %ReverseFoo = ( test_plugin('ReverseFoo') => { select => '**/foo*' } );
my %RepeatFoo  = ( test_plugin('RepeatFoo')  => { select => '**/foo*' } );
my %CheckUpper = ( test_plugin('CheckUpper') => { select => '**/*.txt' } );
my %AToZ       = ( test_plugin('AToZ')       => { select => '**/*.txt' } );

my $cli_conf = <<'EOF';
backup_ttl = 15m
verbose = 1
ignore  = global_ignore/*

[+TestHelper::Plugin::UpperText]
select = **/*.txt
ignore = plugin_ignore/*

[+TestHelper::Plugin::RepeatFoo]
select = **/foo*
times = 3
EOF

sub test_basic : Tests {
    my $self = shift;

    $self->tidy(
        plugins => {},
        source  => { 'foo.txt' => 'abc' },
        dest    => { 'foo.txt' => 'abc' },
        desc    => 'one file no plugins',
    );
    $self->tidy(
        plugins => {%UpperText},
        source  => { 'foo.txt' => 'abc' },
        dest    => { 'foo.txt' => 'ABC' },
        desc    => 'one file UpperText',
    );
    $self->tidy(
        plugins => {
            test_plugin('UpperText')  => { select => '**/*.txt', only_modes => 'upper' },
            test_plugin('ReverseFoo') => { select => '**/foo*',  only_modes => 'reversals' }
        },
        source  => { 'foo.txt' => 'abc' },
        dest    => { 'foo.txt' => 'cba' },
        desc    => 'one file reversals mode',
        options => { mode      => 'reversals' },
    );
    $self->tidy(
        plugins => { %UpperText, %ReverseFoo },
        source  => {
            'foo.txt' => 'abc',
            'bar.txt' => 'def',
            'foo.tx'  => 'ghi',
            'bar.tx'  => 'jkl'
        },
        dest => {
            'foo.txt' => 'CBA',
            'bar.txt' => 'DEF',
            'foo.tx'  => 'ihg',
            'bar.tx'  => 'jkl'
        },
        desc => 'four files UpperText ReverseFoo',
    );
    $self->tidy(
        plugins => {%UpperText},
        source  => { 'foo.txt' => 'abc1' },
        dest    => { 'foo.txt' => 'abc1' },
        desc    => 'one file UpperText errors',
        errors  => qr/non-alpha content/
    );
    $self->tidy(
        plugins => {%UpperText},
        options => {
            ignore => ['global_ignore/*'],
        },
        source => {
            'global_ignore/foo.txt' => 'abc',
            'plugin_ignore/bar.txt' => 'def',
        },
        dest => {
            'global_ignore/foo.txt' => 'abc',
            'plugin_ignore/bar.txt' => 'def',
        },
        desc => 'global and plugin ignores',
    );
}

sub test_filemode : Tests {
    my $self = shift;

    if ( $^O =~ /Win32/ ) {
        $self->builder->skip('file mode on Win32 is weird');
        return;
    }

    my $root_dir = $self->create_dir( { 'foo.txt' => 'abc' } );
    my $file = $root_dir->child('foo.txt');
    $file->chmod('0755');
    my $ct = Code::TidyAll->new(
        plugins  => { test_plugin('UpperText') => { select => '**/foo*' } },
        root_dir => $root_dir,
    );
    $ct->process_paths($file);
    is( $file->slurp,      'ABC' );
    is( $file->stat->mode, 0100755 );
}

sub test_multiple_plugin_instances : Tests {
    my $self = shift;
    $self->tidy(
        plugins => {
            test_plugin('RepeatFoo for txt') => { select => '**/*.txt', times => 2 },
            test_plugin('RepeatFoo for foo') => { select => '**/foo.*', times => 3 },
            %UpperText
        },
        source => { 'foo.txt' => 'abc', 'foo.dat' => 'def', 'bar.txt' => 'ghi' },
        dest   => {
            'foo.txt' => scalar( 'ABC' x 6 ),
            'foo.dat' => scalar( 'def' x 3 ),
            'bar.txt' => scalar( 'GHI' x 2 )
        }
    );
}

sub test_plugin_order_and_atomicity : Tests {
    my $self    = shift;
    my @plugins = map {
        (
            %ReverseFoo,
            test_plugin("UpperText $_")  => { select => '**/*.txt' },
            test_plugin("CheckUpper $_") => { select => '**/*.txt' },

            # note without the weight here this would run first, and the
            # letters in the photetic words themselves would be reversed
            test_plugin('AlwaysPhonetic') => { select => '**/*.txt', weight => 51 }
            )
    } ( 1 .. 3 );

    $self->tidy(
        plugins => {@plugins},
        options => { verbose => 1 },
        source  => { 'foo.txt' => 'abc' },
        dest    => { 'foo.txt' => 'CHARLIE-BRAVO-ALFA' },
        like_output =>
            qr/.*ReverseFoo, .*UpperText 1, .*UpperText 2, .*UpperText 3, .*CheckUpper 1, .*CheckUpper 2, .*CheckUpper 3/
    );

    $self->tidy(
        plugins => { %AToZ, %ReverseFoo, %CheckUpper },
        options     => { verbose   => 1 },
        source      => { 'foo.txt' => 'abc' },
        dest        => { 'foo.txt' => 'abc' },
        errors      => qr/lowercase found/,
        like_output => qr/foo.txt (.*ReverseFoo, .*CheckUpper)/
    );

}

sub test_quiet_and_verbose : Tests {
    my $self = shift;

    foreach my $state ( 'normal', 'quiet', 'verbose' ) {
        foreach my $error ( 0, 1 ) {
            my $root_dir = $self->create_dir( { 'foo.txt' => ( $error ? '123' : 'abc' ) } );
            my $output = capture_stdout {
                my $ct = Code::TidyAll->new(
                    plugins  => {%UpperText},
                    root_dir => $root_dir,
                    ( $state eq 'normal' ? () : ( $state => 1 ) )
                );
                $ct->process_paths("$root_dir/foo.txt");
            };
            if ($error) {
                like( $output, qr/non-alpha content found/, "non-alpha content found ($state)" );
            }
            else {
                is( $output, "[tidied]  foo.txt\n" ) if $state eq 'normal';
                is( $output, q{} ) if $state eq 'quiet';
                like( $output, qr/purging old backups/, "purging old backups ($state)" )
                    if $state eq 'verbose';
                like(
                    $output,
                    qr/\[tidied\]  foo\.txt \(\+TestHelper::Plugin::UpperText\)/s,
                    "foo.txt ($state)"
                ) if $state eq 'verbose';
            }
        }
    }
}

sub test_iterations : Tests {
    my $self     = shift;
    my $root_dir = $self->create_dir( { 'foo.txt' => 'abc' } );
    my $ct       = Code::TidyAll->new(
        plugins    => { test_plugin('RepeatFoo') => { select => '**/foo*', times => 3 } },
        root_dir   => $root_dir,
        iterations => 2
    );
    my $file = $root_dir->child('foo.txt');
    $ct->process_paths($file);
    is( $file->slurp, scalar( 'abc' x 9 ), '3^2 = 9' );
}

sub test_caching_and_backups : Tests {
    my $self = shift;

    my @chi_or_no_chi = (q{});
    if ( eval 'use CHI; 1' ) {
        push @chi_or_no_chi, 'chi';
    }

    foreach my $chi (@chi_or_no_chi) {
        foreach my $cache_model_class (
            qw(
            Code::TidyAll::CacheModel
            Code::TidyAll::CacheModel::Shared
            )
            ) {
            foreach my $no_cache ( 0 .. 1 ) {
                foreach my $no_backups ( 0 .. 1 ) {
                    my $desc
                        = "(no_cache=$no_cache, no_backups=$no_backups, model=$cache_model_class, cache_class=$chi)";
                    my $root_dir = $self->create_dir( { 'foo.txt' => 'abc' } );
                    my $ct = Code::TidyAll->new(
                        plugins           => {%UpperText},
                        root_dir          => $root_dir,
                        cache_model_class => $cache_model_class,
                        ( $no_cache   ? ( no_cache   => 1 )      : () ),
                        ( $no_backups ? ( no_backups => 1 )      : () ),
                        ( $chi        ? ( cache      => _chi() ) : () ),
                    );
                    my $output;
                    my $file = path( $root_dir, 'foo.txt' );
                    my $go = sub {
                        $output = capture_stdout { $ct->process_paths($file) };
                    };

                    $go->();
                    is( $file->slurp, "ABC", "first file change $desc" );
                    is( $output, "[tidied]  foo.txt\n", "first output $desc" );

                    $go->();
                    if ($no_cache) {
                        is( $output, "[checked] foo.txt\n", "second output $desc" );
                    }
                    else {
                        is( $output, q{}, "second output $desc" );
                    }

                    $file->spew('ABCD');
                    $go->();
                    is( $output, "[checked] foo.txt\n", "third output $desc" );

                    $file->spew('def');
                    $go->();
                    is( $file->slurp, 'DEF', "fourth file change $desc" );
                    is( $output, "[tidied]  foo.txt\n", "fourth output $desc" );

                    my $backup_dir = $ct->data_dir->child('backups');
                    $backup_dir->mkpath( { mode => 0775 } );
                    my @files;
                    find(
                        {
                            follow   => 0,
                            wanted   => sub { push @files, $_ if -f },
                            no_chdir => 1
                        },
                        $backup_dir
                    );

                    if ($no_backups) {
                        ok( @files == 0, "no backup files $desc" );
                    }
                    else {
                        ok(
                            scalar(@files) == 1 || scalar(@files) == 2,
                            "1 or 2 backup files $desc"
                        );
                        foreach my $file (@files) {
                            like(
                                $file,
                                qr|\.tidyall\.d/backups/foo\.txt-\d+-\d+\.bak|,
                                "backup filename $desc"
                            );
                        }
                    }
                }
            }
        }
    }
}

sub _chi {
    my $datastore = {};
    return CHI->new( driver => 'Memory', datastore => $datastore );
}

sub test_selects_and_ignores : Tests {
    my $self = shift;

    my @files = ( 'a/foo.pl', 'b/foo.pl', 'a/foo.pm', 'a/bar.pm', 'b/bar.pm' );
    my $root_dir = $self->create_dir( { map { $_ => 'hi' } @files } );
    my $ct = Code::TidyAll->new(
        root_dir => $root_dir,
        plugins  => {
            test_plugin('UpperText') => {
                select => [qw( **/*.pl **/*.pm b/bar.pm c/bar.pl )],
                ignore => [qw( a/foo.pl **/bar.pm c/baz.pl )],
            }
        }
    );
    cmp_set(
        [ map { $_->stringify } $ct->find_matched_files() ],
        [ "$root_dir/a/foo.pm", "$root_dir/b/foo.pl" ]
    );
    cmp_deeply(
        [ map { $_->name } $ct->plugins_for_path('a/foo.pm') ],
        [ test_plugin('UpperText') ]
    );
}

sub test_shebang : Tests {
    my $self = shift;

    my %files = (
        'a/foo.pl' => '#!/usr/bin/perl',
        'a/foo'    => '#!/usr/bin/perl',
        'a/bar'    => '#!/usr/bin/ruby',
        'a/baz'    => 'just another perl hacker',
        'b/foo'    => '#!/usr/bin/perl6',
        'b/bar'    => '#!/usr/bin/perl5',
        'b/baz'    => '#!perl -w',
        'b/bar.pm' => 'package b::bar;',
    );
    my $root_dir = $self->create_dir( \%files );
    my $ct       = Code::TidyAll->new(
        root_dir => $root_dir,
        plugins  => {
            test_plugin('UpperText') => {
                select  => ['**/*'],
                ignore  => ['**/*.*'],
                shebang => [ 'perl', 'perl5' ],
            }
        }
    );
    cmp_set(
        [ map { $_->stringify } $ct->find_matched_files() ],
        [ map {"$root_dir/$_"} qw( a/foo b/bar b/baz ) ],
    );
}

sub test_dirs : Tests {
    my $self = shift;

    my @files = ( 'a/foo.txt', 'a/bar.txt', 'a/bar.pl', 'b/foo.txt' );
    my $root_dir = $self->create_dir( { map { $_ => 'hi' } @files } );

    foreach my $recursive ( 0 .. 1 ) {
        my @results;
        my $output = capture_merged {
            my $ct = Code::TidyAll->new(
                plugins  => { %UpperText, %ReverseFoo },
                root_dir => $root_dir,
                ( $recursive ? ( recursive => 1 ) : () )
            );
            @results = $ct->process_paths("$root_dir/a");
        };
        if ($recursive) {
            is( @results, 3, '3 results' );
            is( scalar( grep { $_->state eq 'tidied' } @results ), 2, '2 tidied' );
            like( $output, qr/\[tidied\]  a\/foo.txt/ );
            like( $output, qr/\[tidied\]  a\/bar.txt/ );
            is( path( $root_dir, 'a', 'foo.txt' )->slurp, 'IH' );
            is( path( $root_dir, 'a', 'bar.txt' )->slurp, 'HI' );
            is( path( $root_dir, 'a', 'bar.pl' )->slurp,  'hi' );
            is( path( $root_dir, 'b', 'foo.txt' )->slurp, 'hi' );
        }
        else {
            is( @results,           1,       '1 result' );
            is( $results[0]->state, 'error', 'error' );
            like( $output, qr/is a directory/ );
        }
    }
}

sub test_paths_in_messages : Tests {
    my $self = shift;

    $self->tidy(
        plugins => {
            test_plugin('UpperText') => { select => '**/*.txt' },
        },
        options => { check_only => 1 },
        source  => {
            'path/to/file1.txt'        => "abc\n",
            'path/to/longer/file2.txt' => "abc\n",
            'top.txt'                  => "abc\n",
        },
        errors => [
            qr{\[checked\] +path/to/file1\.txt},
            qr{\[checked\] +path/to/longer/file2\.txt},
            qr{\[checked\] +top\.txt},
        ],
    );
}

sub test_errors : Tests {
    my $self = shift;

    my $root_dir = $self->create_dir( { 'foo/bar.txt' => 'abc' } );
    throws_ok { Code::TidyAll->new( root_dir => $root_dir ) } qr/Missing required/;
    throws_ok { Code::TidyAll->new( plugins  => {} ) } qr/Missing required/;

    throws_ok {
        Code::TidyAll->new(
            root_dir    => $root_dir,
            plugins     => {},
            bad_param   => 1,
            worse_param => 2
        );
    }
    qr/unknown constructor params 'bad_param', 'worse_param'/;

    throws_ok {
        Code::TidyAll->new(
            root_dir => $root_dir,
            plugins  => { 'DoesNotExist' => { select => '**/*' } }
        )->plugin_objects;
    }
    qr/could not load plugin class/;

    throws_ok {
        Code::TidyAll->new(
            root_dir => $root_dir,
            plugins  => {
                test_plugin('UpperText') => { select => '**/*', bad_option => 1, worse_option => 2 }
            }
        )->plugin_objects;
    }
    qr/unknown options/;

    my $ct = Code::TidyAll->new( plugins => {%UpperText}, root_dir => $root_dir );
    my $output = capture_stdout { $ct->process_paths("$root_dir/baz/blargh.txt") };
    like( $output, qr/baz\/blargh.txt: not a file or directory/, 'file not found' );

    $output = capture_stdout { $ct->process_paths("$root_dir/foo/bar.txt") };
    is( $output, "[tidied]  foo/bar.txt\n", 'filename output' );
    is( path( $root_dir, 'foo', 'bar.txt' )->slurp, 'ABC', 'tidied' );
    my $other_dir = tempdir_simple();
    $other_dir->child('foo.txt')->spew('ABC');
    throws_ok { $ct->process_paths("$other_dir/foo.txt") } qr/not underneath root dir/;
}

sub test_git_files : Tests {
    my $self = shift;

    # Included examples:
    # * basic modified file
    # * renamed but not modified file (perltidy) -- the -> is in the filename
    # * deleted file
    # * renamed and modified file
    my $status
        = qq{## git-status-porcelain\0 M lib/Code/TidyAll/Git/Util.pm\0R  perltidyrc -> xyz\0perltidyrc\0 M t/lib/Test/Code/TidyAll/Basic.pm\0D  tidyall.ini\0RM weaver.initial\0weaver.ini\0};

    require Code::TidyAll::Git::Util;
    my @files = Code::TidyAll::Git::Util::_parse_status($status);
    is_deeply(
        \@files,
        [
            'lib/Code/TidyAll/Git/Util.pm',
            't/lib/Test/Code/TidyAll/Basic.pm',
            'weaver.initial',
        ]
    );
}

sub test_ignore : Tests {
    my $self = shift;

    my $root_dir = $self->create_dir();
    my $subdir   = $root_dir->child('subdir');

    # global ignores
    #
    $subdir = $root_dir->child('global_ignore');
    $subdir->mkpath( { mode => 0775 } );
    $subdir->child('bar.txt')->spew('bye');

    my $cwd = cwd();
    capture_stdout {
        my $pushed = pushd($root_dir);
        system( $^X, "-I$cwd/lib", "-I$cwd/t/lib", "$cwd/bin/tidyall",
            'global_ignore/bar.txt'
        );
    };
    is(
        $root_dir->child( 'global_ignore', 'bar.txt' )->slurp, 'bye',
        'bar.txt not tidied because of global ignore',
    );

    # plugin ignores
    #
    $subdir = $root_dir->child('plugin_ignore');
    $subdir->mkpath( { mode => 0775 } );
    $subdir->child('bar.txt')->spew('bye');

    $cwd = cwd();
    capture_stdout {
        my $pushed = pushd($root_dir);
        system( $^X, "-I$cwd/lib", "-I$cwd/t/lib", "$cwd/bin/tidyall",
            'plugin_ignore/bar.txt'
        );
    };
    is(
        $root_dir->child( 'global_ignore', 'bar.txt' )->slurp, 'bye',
        'bar.txt not tidied because of plugin ignore',
    );
}

sub test_cli : Tests {
    my $self = shift;
    my $output;

    my @cmd = ( $^X, qw( -Ilib -It/lib bin/tidyall ) );
    my $run = sub { system( @cmd, @_ ) };

    $output = capture_stdout {
        $run->('--version');
    };
    like( $output, qr/tidyall .* on perl/, '--version output' );
    $output = capture_stdout {
        $run->('--help');
    };
    like( $output, qr/Usage.*Options:/s, '--help output' );

    foreach my $conf_name ( 'tidyall.ini', '.tidyallrc' ) {
        subtest(
            "conf at $conf_name",
            sub {
                my $root_dir  = $self->create_dir();
                my $conf_file = $root_dir->child($conf_name);
                $conf_file->spew($cli_conf);

                $root_dir->child('foo.txt')->spew('hello');
                my $output = capture_stdout {
                    $run->( $root_dir->child('foo.txt'), '-v' );
                };

                my ($params_msg)
                    = ( $output =~ /constructing Code::TidyAll with these params:(.*)/ );
                ok( defined($params_msg), 'params msg' );
                like( $params_msg, qr/backup_ttl => '15m'/, 'backup_ttl' );
                like( $params_msg, qr/verbose => '?1'?/,    'verbose' );
                like(
                    $params_msg, qr/\Qroot_dir => '$root_dir'\E/,
                    'root_dir'
                );
                like(
                    $output,
                    qr/\[tidied\]  foo.txt \(.*RepeatFoo, .*UpperText\)/,
                    'foo.txt'
                );
                is(
                    $root_dir->child('foo.txt')->slurp, 'HELLOHELLOHELLO',
                    'tidied'
                );

                my $subdir = $root_dir->child('subdir');
                $subdir->mkpath( { mode => 0775 } );
                $subdir->child('foo.txt')->spew('bye');
                $subdir->child('foo2.txt')->spew('bye');

                my $cwd = cwd();
                capture_stdout {
                    my $pushed = pushd($subdir);
                    system( $^X, "-I$cwd/lib", "-I$cwd/t/lib", "$cwd/bin/tidyall", 'foo.txt' );
                };
                is(
                    $root_dir->child( 'subdir', 'foo.txt' )->slurp, 'BYEBYEBYE',
                    'foo.txt tidied'
                );
                is(
                    $root_dir->child( 'subdir', 'foo2.txt' )->slurp, 'bye',
                    'foo2.txt not tidied'
                );

                subtest(
                    'pipe success',
                    sub {
                        my ( $stdout, $stderr );
                        run3(
                            [ @cmd, '-p', $root_dir->child(qw( does_not_exist foo.txt )) ],
                            \'echo',
                            \$stdout,
                            \$stderr,
                        );
                        is( $stdout, 'ECHOECHOECHO', 'pipe: stdin tidied' );
                        unlike( $stderr, qr/\S/, 'pipe: no stderr' );
                    }
                );

                subtest(
                    'pipe error',
                    sub {
                        my ( $stdout, $stderr );
                        run3(
                            [ @cmd, '--pipe', $root_dir->child('foo.txt') ],
                            \'abc1',
                            \$stdout,
                            \$stderr,
                        );
                        is( $stdout, 'abc1', 'pipe: stdin mirrored to stdout' );
                        like( $stderr, qr/non-alpha content found/ );
                    }
                );
            }
        );
    }
}

1;
