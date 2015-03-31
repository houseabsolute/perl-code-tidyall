package inc::MyMakeMaker;

use Moose;

use namespace::autoclean;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

override _build_MakeFile_PL_template => sub {
    return super() . do { local $/ = undef; <DATA> };
};

__PACKAGE__->meta->make_immutable;

1;

__DATA__
use inc::Util qw(make_node_symlinks);

make_node_symlinks();

