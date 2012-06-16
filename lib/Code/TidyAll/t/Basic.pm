package Code::TidyAll::t::Basic;
use Cwd qw(realpath);
use Code::TidyAll::Util qw(dirname mkpath read_file tempdir_simple write_file);
use Code::TidyAll;
use Capture::Tiny qw(capture_stdout);
use File::Find qw(find);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

sub test_plugin { "+Code::TidyAll::Test::Plugin::$_[0]" }
my %UpperText  = ( test_plugin('UpperText')  => { select => '**/*.txt' } );
my %ReverseFoo = ( test_plugin('ReverseFoo') => { select => '**/foo*' } );
my %RepeatFoo  = ( test_plugin('RepeatFoo')  => { select => '**/foo*' } );
my ( $conf1, $conf2 );

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

    my $root_dir = $self->create_dir( $params{source} );

    my $options = $params{options} || {};
    my $ct = Code::TidyAll->new(
        plugins   => $params{plugins},
        recursive => 1,
        root_dir  => $root_dir,
        %$options
    );

    my $result;
    my $output = capture_stdout { $result = $ct->process_all() };
    if ( $params{errors} ) {
        like( $output, $params{errors}, "$desc - errors" );
        ok( $result->error_count > 0, "$desc - error_count > 0" );
    }
    else {
        is( $result->error_count, 0, "$desc - error_count == 0" );
    }
    while ( my ( $path, $content ) = each( %{ $params{dest} } ) ) {
        is( read_file("$root_dir/$path"), $content, "$desc - $path content" );
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
                $output = capture_stdout { $ct->process_files($file) };
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

sub test_errors : Tests {
    my $self = shift;

    my $root_dir = $self->create_dir( { "foo/bar.txt" => "abc" } );
    throws_ok { Code::TidyAll->new( root_dir => $root_dir ) } qr/conf_file or plugins required/;
    throws_ok { Code::TidyAll->new( plugins  => {} ) } qr/conf_file or root_dir required/;
    throws_ok {
        Code::TidyAll->new(
            root_dir    => $root_dir,
            plugins     => {},
            bad_param   => 1,
            worse_param => 2
        );
    }
    qr/unknown constructor param\(s\) 'bad_param', 'worse_param'/;
    throws_ok {
        Code::TidyAll->new(
            root_dir => $root_dir,
            plugins  => { 'DoesNotExist' => { select => '**/*' } }
        );
    }
    qr/could not load plugin class/;

    my $ct = Code::TidyAll->new( plugins => {%UpperText}, root_dir => $root_dir );
    my $output = capture_stdout { $ct->process_files("$root_dir/foo/bar.txt") };
    is( $output, "[tidied]  foo/bar.txt\n", "filename output" );
    is( read_file("$root_dir/foo/bar.txt"), "ABC", "tidied" );
    my $other_dir = realpath( tempdir_simple() );
    write_file( "$other_dir/foo.txt", "ABC" );
    throws_ok { $ct->process_files("$other_dir/foo.txt") } qr/not underneath root dir/;
}

sub test_conf_file : Tests {
    my $self      = shift;
    my $root_dir  = $self->create_dir();
    my $conf_file = "$root_dir/tidyall.ini";
    write_file( $conf_file, $conf1 );

    my $ct = Code::TidyAll->new( conf_file => $conf_file );
    my %expected = (
        backup_ttl => 300,
        no_backups => undef,
        no_cache   => 1,
        recursive  => 1,
        root_dir   => dirname($conf_file),
        data_dir   => "$root_dir/.tidyall.d",
        plugins    => {
            PerlTidy   => { argv   => '-noll -it=2', select => '**/*.{pl,pm,t}' },
            PodTidy    => { select => '**/*.{pl,pm,t}' },
            PerlCritic => { argv   => '-severity 3', select => '**/*.pm' },
        }
    );
    while ( my ( $method, $value ) = each(%expected) ) {
        cmp_deeply( $ct->$method, $value, "$method" );
    }
}

sub test_cli : Tests {
    my $self      = shift;
    my $root_dir  = $self->create_dir();
    my $conf_file = "$root_dir/tidyall.ini";
    write_file( $conf_file, $conf2 );

    write_file( "$root_dir/foo.txt", "hello" );
    my $output = capture_stdout {
        system( "$^X", "bin/tidyall", "$root_dir/foo.txt", "-v" );
    };
    my ($params_msg) = ( $output =~ /constructing Code::TidyAll with these params:(.*)/ );
    ok( defined($params_msg), "params msg" );
    like( $params_msg, qr/backup_ttl => '15m'/,                              'backup_ttl' );
    like( $params_msg, qr/verbose => '?1'?/,                                 'verbose' );
    like( $params_msg, qr/\Qroot_dir => '$root_dir'\E/,                      'root_dir' );
    like( $output,     qr/\[tidied\]  foo.txt \(.*RepeatFoo, .*UpperText\)/, 'foo.txt' );
    is( read_file("$root_dir/foo.txt"), "HELLOHELLOHELLO", "tidied" );

    mkpath( "$root_dir/subdir", 0, 0775 );
    write_file( "$root_dir/subdir/foo.txt",  "bye" );
    write_file( "$root_dir/subdir/foo2.txt", "bye" );
    my $cwd = realpath();
    capture_stdout {
        system("cd $root_dir/subdir; $^X $cwd/bin/tidyall foo.txt");
    };
    is( read_file("$root_dir/subdir/foo.txt"),  "BYEBYEBYE", "foo.txt tidied" );
    is( read_file("$root_dir/subdir/foo2.txt"), "bye",       "foo2.txt not tidied" );
}

$conf1 = '
backup_ttl = 5m
no_cache = 1
recursive = 1

[PerlTidy]
argv = -noll -it=2
select = **/*.{pl,pm,t}

[PodTidy]
select = **/*.{pl,pm,t}

[PerlCritic]
argv = -severity 3
select = **/*.pm
';

$conf2 = '
backup_ttl = 15m
verbose = 1

[+Code::TidyAll::Test::Plugin::UpperText]
select = **/*.txt

[+Code::TidyAll::Test::Plugin::RepeatFoo]
select = **/foo*
times = 3
';

1;
