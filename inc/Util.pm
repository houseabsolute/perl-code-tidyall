package Util;

use strict;
use warnings;

use Exporter qw(import);

# We don't want to use Path::Tiny in here since that would require a
# configure-time prereq, which is more trouble than it's worth. This module
# should only use things in the Perl core for simplicit.y
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
