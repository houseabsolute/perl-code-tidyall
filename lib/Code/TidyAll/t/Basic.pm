package Code::TidyAll::t::Basic;
use Cwd qw(realpath);
use Code::TidyAll::Util qw(dirname mkpath read_file tempdir_simple write_file);
use Code::TidyAll;
use Capture::Tiny qw(capture_stdout);
use File::Find qw(find);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

sub test_plugin { "+Code::TidyAll::Test::Plugin::$_[0]" }
my $UpperText  = test_plugin('UpperText');
my $ReverseFoo = test_plugin('ReverseFoo');

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

    my $output = capture_stdout { $ct->process_paths($root_dir) };
    if ( $params{errors} ) {
        like( $output, $params{errors}, "$desc - errors" );
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
        plugins => { $UpperText => {} },
        source  => { "foo.txt"  => "abc" },
        dest    => { "foo.txt"  => "ABC" },
        desc    => 'one file UpperText',
    );
    $self->tidy(
        plugins => { $UpperText => {}, $ReverseFoo => {} },
        source => { "foo.txt" => "abc", "bar.txt" => "def", "foo.tx" => "ghi", "bar.tx" => "jkl" },
        dest   => { "foo.txt" => "CBA", "bar.txt" => "DEF", "foo.tx" => "ihg", "bar.tx" => "jkl" },
        desc => 'four files UpperText ReverseFoo',
    );
    $self->tidy(
        plugins => { $UpperText => {} },
        source  => { "foo.txt"  => "abc1" },
        dest    => { "foo.txt"  => "abc1" },
        desc    => 'one file UpperText errors',
        errors  => qr/non-alpha content/
    );
}

sub test_caching_and_backups : Tests {
    my $self = shift;

    my $root_dir = $self->create_dir( { "foo.txt" => "abc" } );
    my $ct = Code::TidyAll->new( plugins => { $UpperText => {} }, root_dir => $root_dir );
    my $output;
    my $file = "$root_dir/foo.txt";
    my $go   = sub {
        $output = capture_stdout { $ct->process_paths($file) };
    };

    $go->();
    is( read_file($file), "ABC",       "file changed" );
    is( $output,          "foo.txt\n", 'output' );

    $go->();
    is( $output, '', 'no output' );

    write_file( $file, "def" );
    $go->();
    is( read_file($file), "DEF",       "file changed" );
    is( $output,          "foo.txt\n", 'output' );

    my $backup_dir = $ct->data_dir . "/backups";
    my @files;
    find( { follow => 0, wanted => sub { push @files, $_ if -f }, no_chdir => 1 }, $backup_dir );
    ok( scalar(@files) == 1 || scalar(@files) == 2, "1 or 2 backup files" );
    foreach my $file (@files) {
        like( $file, qr|\.tidyall\.d/backups/foo\.txt-\d+-\d+\.bak|, "backup filename" );
    }
}

sub test_errors : Tests {
    my $self = shift;

    my $data_dir = tempdir_simple();
    throws_ok { Code::TidyAll->new( data_dir => $data_dir ) } qr/conf_file or plugins required/;
    throws_ok { Code::TidyAll->new( plugins  => {} ) } qr/conf_file or root_dir required/;

    my $root_dir = $self->create_dir( { "foo/bar.txt" => "abc" } );
    my $ct = Code::TidyAll->new( plugins => { $UpperText => {} }, root_dir => $root_dir );
    my $output = capture_stdout { $ct->process_paths("$root_dir/foo/bar.txt") };
    is( $output,                            "foo/bar.txt\n", "filename output" );
    is( read_file("$root_dir/foo/bar.txt"), "ABC",           "tidied" );
    $output = capture_stdout { $ct->process_paths("$root_dir/foo") };
    is( $output, "foo: skipping dir, not in recursive mode\n" );
    my $other_dir = realpath( tempdir_simple() );
    write_file( "$other_dir/foo.txt", "ABC" );
    $output = capture_stdout { $ct->process_paths("$other_dir/foo.txt") };
    like( $output, qr/foo.txt: skipping, not underneath root dir/ );
}

1;
