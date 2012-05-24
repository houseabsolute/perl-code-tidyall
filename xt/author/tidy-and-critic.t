#!perl
use Code::TidyAll::Util qw(read_file tempdir_simple write_file);
use Code::TidyAll;
use File::Basename;
use File::Path;
use Test::More;
use Capture::Tiny qw(capture_merged);

my $root_dir = tempdir_simple('Code-TidyAll-XXXX');

sub make {
    my ( $file, $content ) = @_;
    $file = "$root_dir/$file";
    mkpath( dirname($file), 0, 0775 );
    write_file( $file, $content );
}

sub got_errors {
    my ($output) = @_;
    like( $output, qr/\*\*\*/, 'has errors' );
}

sub got_no_errors {
    my ($output) = @_;
    unlike( $output, qr/\*\*\*/, 'has no errors' );
}

make(
    "lib/Foo.pm",
    'package Foo;
  use strict;
1;
'
);
make( "bin/bar.pl",    "#!/usr/bin/perl\n  $d = 5;" );
make( "data/baz.txt",  "    34" );
make( ".perlcriticrc", "include = RequireUseStrict" );

my $ct = Code::TidyAll->new(
    root_dir => $root_dir,
    plugins  => {
        perltidy   => {},
        perlcritic => {},
    }
);
my $output;
$output = capture_merged { $ct->tidyall() };
like( $output, qr/.*bar\.pl\n.*Code before strictures are enabled.*/ );
like( $output, qr/.*Foo\.pm/ );
is( read_file("$root_dir/lib/Foo.pm"),   "package Foo;\nuse strict;\n1;\n" );
is( read_file("$root_dir/data/baz.txt"), "    34" );
got_errors($output);

$output = capture_merged { $ct->tidyall() };
like( $output, qr/.*bar\.pl\n.*Code before strictures are enabled.*/ );
unlike( $output, qr/Foo\.pm/ );
got_errors($output);

make( "bin/bar.pl", "#!/usr/bin/perl\nuse strict;\n  \$d = 5;" );
$output = capture_merged { $ct->tidyall() };
like( $output, qr/.*bar\.pl/ );
got_no_errors($output);
is( read_file("$root_dir/bin/bar.pl"), "#!/usr/bin/perl\nuse strict;\n\$d = 5;\n" );

$output = capture_merged { $ct->tidyall() };
is($output, '', 'no output');

done_testing();
