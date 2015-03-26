package inc::MakeNodeSymlinks;

use strict;
use warnings;
use namespace::autoclean;

use Code::TidyAll::Util qw(pushd);
use File::Path qw(mkpath);

use Moose;

with 'Dist::Zilla::Role::AfterBuild';

sub after_build {
    my $self   = shift;
    my $config = shift;

    my $bin = "$config->{build_root}/node_modules/.bin";
    mkpath( $bin, 0, 0755 );
    my $pushed = pushd($bin);

    my %links = (
        'css-beautify'  => '../js-beautify/js/bin/css-beautify.js',
        'cssunminifier' => '../cssunminifier/bin/cssunminifier',
        'html-beautify' => '../js-beautify/js/bin/html-beautify.js',
        'js-beautify'   => '../js-beautify/js/bin/js-beautify.js',
        'jshint'        => '../jshint/bin/jshint',
        'jslint'        => '../jslint/bin/jslint.js',
    );
    for my $from ( keys %links ) {
        symlink $links{$from}, $from unless -l $from || -f _;
    }
}

__PACKAGE__->meta->make_immutable;

1;
