package Test::Code::TidyAll::Basic;

use Cwd qw(realpath);
use Code::TidyAll::Util qw(dirname mkpath pushd read_file tempdir_simple write_file);
use Code::TidyAll;
use Capture::Tiny qw(capture capture_stdout capture_merged);
use File::Find qw(find);
use File::pushd qw(pushd);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

sub test_plugin { "+Code::TidyAll::Test::Plugin::$_[0]" }
my %UpperText  = ( test_plugin('UpperText')  => { select => '**/*.txt' } );
my %ReverseFoo = ( test_plugin('ReverseFoo') => { select => '**/foo*' } );
my %RepeatFoo  = ( test_plugin('RepeatFoo')  => { select => '**/foo*' } );
my %CheckUpper = ( test_plugin('CheckUpper') => { select => '**/*.txt' } );
my %AToZ       = ( test_plugin('AToZ')       => { select => '**/*.txt' } );

my $cli_conf;

sub create_dir {
    my ( $self, $files ) = @_;

    my $root_dir = tempdir_simple();
    while ( my ( $path, $content ) = each(%$files) ) {
        my $full_path = "$root_dir/$path";
        mkpath( dirname($full_path), 0, 0775 );
        write_file( $full_path, $content );
    }
    return realpath($root_dir);
}

sub tidy {
    my ( $self, %params ) = @_;
    my $desc = $params{desc};
    if ( !defined($desc) ) {
        ($desc) = ( ( caller(1) )[3] =~ /([^:]+$)/ );
    }

    my $root_dir = $self->create_dir( $params{source} );

    my $options = $params{options} || {};
    my $ct = Code::TidyAll->new(
        plugins  => $params{plugins},
        root_dir => $root_dir,
        %$options
    );

    my @results;
    my $output = capture_stdout { @results = $ct->process_all() };
    my $error_count = grep { $_->error } @results;
    if ( $params{errors} ) {
        like( $output, $params{errors}, "$desc - errors" );
        ok( $error_count > 0, "$desc - error_count > 0" );
    }
    else {
        is( $error_count, 0, "$desc - error_count == 0" );
    }
    while ( my ( $path, $content ) = each( %{ $params{dest} } ) ) {
        is( read_file("$root_dir/$path"), $content, "$desc - $path content" );
    }
    if ( my $like_output = $params{like_output} ) {
        like( $output, $like_output, "$desc - output" );
    }
}

sub test_basic : Tests {
    my $self = shift;

    $self->tidy(
        plugins => {},
        source  => { "foo.txt" => "abc" },
        dest    => { "foo.txt" => "abc" },
        desc    => 'one file no plugins',
    );
    $self->tidy(
        plugins => {%UpperText},
        source  => { "foo.txt" => "abc" },
        dest    => { "foo.txt" => "ABC" },
        desc    => 'one file UpperText',
    );
    $self->tidy(
        plugins => {
            test_plugin('UpperText')  => { select => '**/*.txt', only_modes => 'upper' },
            test_plugin('ReverseFoo') => { select => '**/foo*',  only_modes => 'reversals' }
        },
        source  => { "foo.txt" => "abc" },
        dest    => { "foo.txt" => "cba" },
        desc    => 'one file reversals mode',
        options => { mode      => 'reversals' },
    );
    $self->tidy(
        plugins => { %UpperText, %ReverseFoo },
        source  => {
            "foo.txt" => "abc",
            "bar.txt" => "def",
            "foo.tx"  => "ghi",
            "bar.tx"  => "jkl"
        },
        dest => {
            "foo.txt" => "CBA",
            "bar.txt" => "DEF",
            "foo.tx"  => "ihg",
            "bar.tx"  => "jkl"
        },
        desc => 'four files UpperText ReverseFoo',
    );
    $self->tidy(
        plugins => {%UpperText},
        source  => { "foo.txt" => "abc1" },
        dest    => { "foo.txt" => "abc1" },
        desc    => 'one file UpperText errors',
        errors  => qr/non-alpha content/
    );
}

sub test_multiple_plugin_instances : Tests {
    my $self = shift;
    $self->tidy(
        plugins => {
            test_plugin('RepeatFoo for txt') => { select => '**/*.txt', times => 2 },
            test_plugin('RepeatFoo for foo') => { select => '**/foo.*', times => 3 },
            %UpperText
        },
        source => { "foo.txt" => "abc", "foo.dat" => "def", "bar.txt" => "ghi" },
        dest   => {
            "foo.txt" => scalar( "ABC" x 6 ),
            "foo.dat" => scalar( "def" x 3 ),
            "bar.txt" => scalar( "GHI" x 2 )
        }
    );
}

sub test_plugin_order_and_atomicity : Tests {
    my $self    = shift;
    my @plugins = map {
        (
            %ReverseFoo,
            test_plugin("UpperText $_")  => { select => '**/*.txt' },
            test_plugin("CheckUpper $_") => { select => '**/*.txt' }
          )
    } ( 1 .. 3 );
    my $output = capture_stdout {
        $self->tidy(
            plugins => {@plugins},
            options => { verbose => 1 },
            source  => { "foo.txt" => "abc" },
            dest    => { "foo.txt" => "CBA" },
            like_output =>
              qr/.*ReverseFoo, .*UpperText 1, .*UpperText 2, .*UpperText 3, .*CheckUpper 1, .*CheckUpper 2, .*CheckUpper 3/
        );
    };

    $self->tidy(
        plugins => { %AToZ, %ReverseFoo, %CheckUpper },
        options     => { verbose   => 1 },
        source      => { "foo.txt" => "abc" },
        dest        => { "foo.txt" => "abc" },
        errors      => qr/lowercase found/,
        like_output => qr/foo.txt (.*ReverseFoo, .*CheckUpper)/
    );

}

sub test_quiet_and_verbose : Tests {
    my $self = shift;

    foreach my $state ( 'normal', 'quiet', 'verbose' ) {
        foreach my $error ( 0, 1 ) {
            my $root_dir = $self->create_dir( { "foo.txt" => ( $error ? "123" : "abc" ) } );
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
                is( $output, "" ) if $state eq 'quiet';
                like( $output, qr/purging old backups/, "purging old backups ($state)" )
                  if $state eq 'verbose';
                like(
                    $output,
                    qr/\[tidied\]  foo\.txt \(\+Code::TidyAll::Test::Plugin::UpperText\)/s,
                    "foo.txt ($state)"
                ) if $state eq 'verbose';
            }
        }
    }
}

sub test_iterations : Tests {
    my $self     = shift;
    my $root_dir = $self->create_dir( { "foo.txt" => "abc" } );
    my $ct       = Code::TidyAll->new(
        plugins    => { test_plugin('RepeatFoo') => { select => '**/foo*', times => 3 } },
        root_dir   => $root_dir,
        iterations => 2
    );
    my $file = "$root_dir/foo.txt";
    $ct->process_paths($file);
    is( read_file($file), scalar( "abc" x 9 ), "3^2 = 9" );
}

sub test_caching_and_backups : Tests {
    my $self = shift;

    foreach my $no_cache ( 0 .. 1 ) {
        foreach my $no_backups ( 0 .. 1 ) {
            my $desc     = "(no_cache=$no_cache, no_backups=$no_backups)";
            my $root_dir = $self->create_dir( { "foo.txt" => "abc" } );
            my $ct       = Code::TidyAll->new(
                plugins  => {%UpperText},
                root_dir => $root_dir,
                ( $no_cache   ? ( no_cache   => 1 ) : () ),
                ( $no_backups ? ( no_backups => 1 ) : () )
            );
            my $output;
            my $file = "$root_dir/foo.txt";
            my $go   = sub {
                $output = capture_stdout { $ct->process_paths($file) };
            };

            $go->();
            is( read_file($file), "ABC", "first file change $desc" );
            is( $output, "[tidied]  foo.txt\n", "first output $desc" );

            $go->();
            if ($no_cache) {
                is( $output, "[checked] foo.txt\n", "second output $desc" );
            }
            else {
                is( $output, '', "second output $desc" );
            }

            write_file( $file, "ABCD" );
            $go->();
            is( $output, "[checked] foo.txt\n", "third output $desc" );

            write_file( $file, "def" );
            $go->();
            is( read_file($file), "DEF", "fourth file change $desc" );
            is( $output, "[tidied]  foo.txt\n", "fourth output $desc" );

            my $backup_dir = $ct->data_dir . "/backups";
            mkpath( $backup_dir, 0, 0775 );
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
                ok( scalar(@files) == 1 || scalar(@files) == 2, "1 or 2 backup files $desc" );
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

sub test_selects_and_ignores : Tests {
    my $self = shift;

    my @files = ( "a/foo.pl", "b/foo.pl", "a/foo.pm", "a/bar.pm", "b/bar.pm" );
    my $root_dir = $self->create_dir( { map { $_ => 'hi' } @files } );
    my $ct = Code::TidyAll->new(
        root_dir => $root_dir,
        plugins  => {
            test_plugin('UpperText') => {
                select => '**/*.pl **/*.pm b/bar.pm c/bar.pl',
                ignore => 'a/foo.pl **/bar.pm c/baz.pl'
            }
        }
    );
    cmp_set( [ $ct->find_matched_files() ], [ "$root_dir/a/foo.pm", "$root_dir/b/foo.pl" ] );
    cmp_deeply( [ map { $_->name } $ct->plugins_for_path("a/foo.pm") ],
        [ test_plugin('UpperText') ] );
}

sub test_dirs : Tests {
    my $self = shift;

    my @files = ( "a/foo.txt", "a/bar.txt", "a/bar.pl", "b/foo.txt" );
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
            is( @results, 3, "3 results" );
            is( scalar( grep { $_->state eq 'tidied' } @results ), 2, "2 tidied" );
            like( $output, qr/\[tidied\]  a\/foo.txt/ );
            like( $output, qr/\[tidied\]  a\/bar.txt/ );
            is( read_file("$root_dir/a/foo.txt"), "IH" );
            is( read_file("$root_dir/a/bar.txt"), "HI" );
            is( read_file("$root_dir/a/bar.pl"),  "hi" );
            is( read_file("$root_dir/b/foo.txt"), "hi" );
        }
        else {
            is( @results,           1,       "1 result" );
            is( $results[0]->state, "error", "error" );
            like( $output, qr/is a directory/ );
        }
    }
}

sub test_errors : Tests {
    my $self = shift;

    my $root_dir = $self->create_dir( { "foo/bar.txt" => "abc" } );
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
    like( $output, qr/baz\/blargh.txt: not a file or directory/, "file not found" );

    $output = capture_stdout { $ct->process_paths("$root_dir/foo/bar.txt") };
    is( $output, "[tidied]  foo/bar.txt\n", "filename output" );
    is( read_file("$root_dir/foo/bar.txt"), "ABC", "tidied" );
    my $other_dir = realpath( tempdir_simple() );
    write_file( "$other_dir/foo.txt", "ABC" );
    throws_ok { $ct->process_paths("$other_dir/foo.txt") } qr/not underneath root dir/;
}

sub test_cli : Tests {
    my $self = shift;
    my $output;

    my @cmd = ( $^X, qw( -Ilib -It/lib bin/tidyall ) );
    my $run = sub { system( @cmd, @_ ) };

    $output = capture_stdout {
        $run->("--version");
    };
    like( $output, qr/tidyall .* on perl/, '--version output' );
    $output = capture_stdout {
        $run->("--help");
    };
    like( $output, qr/Usage.*Options:/s, '--help output' );

    foreach my $conf_name ( "tidyall.ini", ".tidyallrc" ) {
        subtest(
            "conf at $conf_name",
            sub {
                my $root_dir  = $self->create_dir();
                my $conf_file = "$root_dir/$conf_name";
                write_file( $conf_file, $cli_conf );

                write_file( "$root_dir/foo.txt", "hello" );
                my $output = capture_stdout {
                    $run->( "$root_dir/foo.txt", "-v" );
                };

                my ($params_msg)
                    = ( $output
                        =~ /constructing Code::TidyAll with these params:(.*)/
                    );
                ok( defined($params_msg), "params msg" );
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
                    read_file("$root_dir/foo.txt"), "HELLOHELLOHELLO",
                    "tidied"
                );

                mkpath( "$root_dir/subdir", 0, 0775 );
                write_file( "$root_dir/subdir/foo.txt",  "bye" );
                write_file( "$root_dir/subdir/foo2.txt", "bye" );
                my $cwd = realpath();
                capture_stdout {
                    my $dir = pushd "$root_dir/subdir";
                    system($^X, "-I$cwd/lib", "-I$cwd/t/lib", "$cwd/bin/tidyall", 'foo.txt');
                };
                is(
                    read_file("$root_dir/subdir/foo.txt"), "BYEBYEBYE",
                    "foo.txt tidied"
                );
                is(
                    read_file("$root_dir/subdir/foo2.txt"), "bye",
                    "foo2.txt not tidied"
                );

                # -p / --pipe success
                #
                my ( $stdout, $stderr ) = capture {
                    open(
                        my $fh, "|-", @cmd, "-p",
                        "$root_dir/does_not_exist/foo.txt"
                    );
                    print $fh "echo";
                };
                is( $stdout, "ECHOECHOECHO", "pipe: stdin tidied" );
                unlike( $stderr, qr/\S/, "pipe: no stderr" );

                # -p / --pipe error
                #
                ( $stdout, $stderr ) = capture {
                    open( my $fh, "|-", @cmd, "--pipe", "$root_dir/foo.txt" );
                    print $fh "abc1";
                };
                is( $stdout, "abc1", "pipe: stdin mirrored to stdout" );
                like( $stderr, qr/non-alpha content found/ );
            }
        );
    }
}

$cli_conf = '
backup_ttl = 15m
verbose = 1

[+Code::TidyAll::Test::Plugin::UpperText]
select = **/*.txt

[+Code::TidyAll::Test::Plugin::RepeatFoo]
select = **/foo*
times = 3
';

1;
