#!/usr/bin/perl
use lib 't/lib';
use Code::TidyAll::Util qw(tempdir_simple);
use Code::TidyAll;
use Path::Tiny qw(path);
use Test::More;
use Capture::Tiny qw(capture_merged);

my $root_dir = tempdir_simple('Code-TidyAll-XXXX');

sub make {
    my ( $file, $content ) = @_;
    $file = $root_dir->child($file);
    $file->parent->mkpath( { mode => 0755 } );
    $file->spew($content);
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
is( $root_dir->child(qw(lib Foo.pm))->slurp, "package Foo;\nuse strict;\n1;\n" );
is(
    $root_dir->child(qw(lib Foo.pod))->slurp,
    "=over\n\n=item a\n\n"
        . join( " ", ("Blah") x 16 ) . "\n"
        . join( " ", ("Blah") x 9 )
        . "\n\n=back\n"
);
is( $root_dir->child(qw(data baz.txt))->slurp, "    34" );

$output = capture_merged { $ct->process_all() };
like( $output, qr/Code before strictures are enabled./ );
unlike( $output, qr/Foo\.pm/ );

make( "bin/bar.pl", "#!/usr/bin/perl\nuse strict;\n  \$d = 5;" );
$output = capture_merged { $ct->process_all() };
like( $output, qr/.*bar\.pl/ );
is( $root_dir->child(qw(bin bar.pl))->slurp, "#!/usr/bin/perl\nuse strict;\n\$d = 5;\n" );

done_testing();
