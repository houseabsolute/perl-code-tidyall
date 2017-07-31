package TestFor::Code::TidyAll::SpacesInPaths;

use strict;
use warnings;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

use Code::TidyAll::Util qw(tempdir_simple);

sub _extra_path {
    (
        'node_modules/.bin',
        'php5/usr/bin',
    );
}

sub test_css_unminifier : Tests {
    my $self = shift;

    return unless $self->require_executable('node');
    return unless $self->require_executable('cssunminifier');

    my $file   = $self->_spaces_dir->child('foo bar.css');
    my $source = "body {\nfont-family:helvetica;\nfont-size:15pt;\n}";
    $file->spew($source);

    $self->tidyall(
        plugin_conf => {
            CSSUnminifier => { select => '**/*.css' },
        },
        source_file => $file,
        expect_tidy => "body {\n    font-family: helvetica;\n    font-size: 15pt;\n}\n"
    );
}

sub test_js_plugins : Tests {
    my $self = shift;

    return unless $self->require_executable('node');
    return unless $self->require_executable('js-beautify');
    return unless $self->require_executable('jshint');
    return unless $self->require_executable('jslint');

    my $file = $self->_spaces_dir->child('foo bar.js');
    $file->spew('var my_object = {};');

    $self->tidyall(
        plugin_conf => {
            JSBeautify => { select => '**/*.js' },
            JSHint     => { select => '**/*.js' },
            JSLint     => { select => '**/*.js' },
        },
        source_file => $file,
        expect_ok   => 1,
    );
}

sub test_mason_tidy : Tests {
    my $self = shift;

    my $file   = $self->_spaces_dir->child('foo bar.mason');
    my $source = "%if(\$foo) {\n%bar(1,2);\n%}";
    $file->spew($source);

    $self->tidyall(
        plugin_conf => {
            MasonTidy => {
                argv   => '-m 1 ',
                select => '**/*.mason'
            },
        },
        source_file => $file,
        expect_tidy => "% if (\$foo) {\n%     bar( 1, 2 );\n% }",
    );
}

sub test_perl_plugins : Tests {
    my $self = shift;

    my $file   = $self->_spaces_dir->child('foo bar.pl');
    my $source = <<'EOF';
use strict;
use warnings;

my $foo = 42;
print $foo or die $!;

__END__

=pod

=head1 NAME

Some useless junk

=cut
EOF

    $file->spew($source);

    my %plugins = (
        PerlCritic => {
            argv   => '--gentle',
            select => '**/*.pl'
        },
        PerlTidy      => { select => '**/*.pl' },
        PerlTidySweet => { select => '**/*.pl' },
        PodChecker    => { select => '**/*.pl' },
        PodTidy       => { select => '**/*.pl' },
    );

    # No ispell on Windows
    $plugins{PodSpell} = { select => '**/*.pl' }
        unless $^O eq 'MSWin32';

    $self->tidyall(
        plugin_conf => \%plugins,
        source_file => $file,
        expect_ok   => 1,
    );
}

sub test_php_code_sniffer : Tests {
    my $self = shift;

    return unless $self->require_executable('php');
    return unless $self->require_executable('phpcs');

    my $file   = $self->_spaces_dir->child('foo bar.php');
    my $source = '<?php function foo() { $bar = 5 } ?>';
    $file->spew($source);

    $self->tidyall(
        plugin_conf => {
            PHPCodeSniffer => {
                argv   => '--severity=6',
                select => '**/*.php'
            },
        },
        source_file => $file,
        expect_ok   => 1,
    );
}

sub _spaces_dir {
    my $self = shift;

    return $self->{spaces_dir} ||= do {
        my $dir = $self->{root_dir}->child('has spaces');
        $dir->mkpath( { mode => 0755 } );
        $dir;
    };
}

1;
