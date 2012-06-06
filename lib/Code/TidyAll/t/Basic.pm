package Code::TidyAll::t::Basic;
use Code::TidyAll::Util qw(mkpath read_file tempdir_simple write_file);
use Code::TidyAll;
use File::Basename;
use File::Path;
use Capture::Tiny qw(capture);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

sub tidy {
    my ( $self, %params ) = @_;
    my $desc = $params{desc};

    my $temp_dir    = tempdir_simple();
    my $content_dir = "$temp_dir/content";
    my $data_dir    = "$temp_dir/data";
    mkpath( $content_dir, 0, 0775 );

    while ( my ( $path, $content ) = each( %{ $params{source} } ) ) {
        write_file( "$content_dir/$path", $content );
    }

    my %plugins =
      map { ( "+Code::TidyAll::Test::Plugin::$_", $params{plugins}->{$_} ) }
      keys( %{ $params{plugins} } );
    my $ct = Code::TidyAll->new( plugins => \%plugins, recursive => 1, data_dir => $data_dir );

    my ( $stdout, $stderr ) = capture { $ct->process_dir($content_dir) };
    if ( $params{errors} ) {
        like( $stderr, $params{errors}, "$desc - errors" );
    }
    else {
        ok( $stderr !~ /\S/, "$desc - no errors ($stderr)" );
    }
    while ( my ( $path, $content ) = each( %{ $params{dest} } ) ) {
        is( read_file("$content_dir/$path"), $content, "$desc - $path content" );
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
        plugins => { 'UpperText' => {} },
        source  => { "foo.txt"   => "abc" },
        dest    => { "foo.txt"   => "ABC" },
        desc    => 'one file UpperText',
    );
    $self->tidy(
        plugins => { 'UpperText' => {}, 'ReverseFoo' => {} },
        source => { "foo.txt" => "abc", "bar.txt" => "def", "foo.tx" => "ghi", "bar.tx" => "jkl" },
        dest   => { "foo.txt" => "CBA", "bar.txt" => "DEF", "foo.tx" => "ihg", "bar.tx" => "jkl" },
        desc => 'four files UpperText ReverseFoo',
    );
    $self->tidy(
        plugins => { 'UpperText' => {} },
        source  => { "foo.txt"   => "abc1" },
        dest    => { "foo.txt"   => "abc1" },
        desc    => 'one file UpperText errors',
        errors  => qr/non-alpha content/
    );
}

sub test_construct_errors : Tests {
    my $self = shift;

    my $data_dir = tempdir_simple();
    throws_ok { Code::TidyAll->new( data_dir => $data_dir ) } qr/conf_file or plugins required/;
    throws_ok { Code::TidyAll->new( plugins  => {} ) } qr/conf_file or data_dir required/;
}

1;
