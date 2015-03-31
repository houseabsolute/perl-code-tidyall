package inc::Util;

use strict;
use warnings;

use Exporter qw(import);
use File::Path qw(mkpath);

our @EXPORT_OK = qw(make_node_symlinks);

sub make_node_symlinks {
    return unless eval {
        no warnings 'uninitialized';
        symlink( qw{}, q{} );
        1;
    };

    my %links = (
        'css-beautify'  => '../js-beautify/js/bin/css-beautify.js',
        'cssunminifier' => '../cssunminifier/bin/cssunminifier',
        'html-beautify' => '../js-beautify/js/bin/html-beautify.js',
        'js-beautify'   => '../js-beautify/js/bin/js-beautify.js',
        'jshint'        => '../jshint/bin/jshint',
        'jslint'        => '../jslint/bin/jslint.js',
    );

    my $bin = 'node_modules/.bin';
    mkpath( $bin, 0, 0755 );
    chdir $bin or die "Cannot chdir to $bin: $!";

    for my $from ( keys %links ) {
        symlink $links{$from}, $from unless -l $from || -f _;
    }
}

1;
