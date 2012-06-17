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

make(
    "lib/Foo.pm",
    'package Foo;
  use strict;
1;
'
);
make( "bin/bar.pl",    "#!/usr/bin/perl\n  \$d = 5;" );
make( "lib/Foo.pod",   "=over\n\n=item a\n\n" . scalar( "Blah " x 25 ) . "\n\n=back\n" );
make( "data/baz.txt",  "    34" );
make( ".perlcriticrc", "include = RequireUseStrict" );

my $ct = Code::TidyAll->new(
    root_dir => $root_dir,
    plugins  => {
        PerlTidy   => { select => '**/*.{pl,pm}' },
        PerlCritic => { select => '**/*.{pl,pm}', argv => "--profile $root_dir/.perlcriticrc" },
        PodTidy    => { select => '**/*.pod' },
    }
);
my $output;
$output = capture_merged { $ct->process_all() };
like( $output, qr/Code before strictures are enabled./ );
is( read_file("$root_dir/lib/Foo.pm"), "package Foo;\nuse strict;\n1;\n" );
is( read_file("$root_dir/lib/Foo.pod"),
        "=over\n\n=item a\n\n"
      . join( " ", ("Blah") x 16 ) . "\n"
      . join( " ", ("Blah") x 9 )
      . "\n\n=back\n" );
is( read_file("$root_dir/data/baz.txt"), "    34" );

$output = capture_merged { $ct->process_all() };
like( $output, qr/Code before strictures are enabled./ );
unlike( $output, qr/Foo\.pm/ );

make( "bin/bar.pl", "#!/usr/bin/perl\nuse strict;\n  \$d = 5;" );
$output = capture_merged { $ct->process_all() };
like( $output, qr/.*bar\.pl/ );
is( read_file("$root_dir/bin/bar.pl"), "#!/usr/bin/perl\nuse strict;\n\$d = 5;\n" );

done_testing();
