package TestFor::Code::TidyAll::SpacesInPaths;

use strict;
use warnings;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

use Code::TidyAll::Plugin::PerlCritic;
use Code::TidyAll::Util qw(tempdir_simple);
use Module::Runtime     qw( require_module );
use Path::Tiny          qw( cwd );
use Try::Tiny;

BEGIN {
    my @mods
        = qw( Mason::Tidy Perl::Critic Perl::Tidy Perl::Tidy::Sweetened Pod::Checker Pod::Tidy );
    push @mods, 'Pod::Spell'
        unless $^O eq 'MSWin32';
    for my $mod (@mods) {
        unless ( try { require_module($mod); 1 } ) {
            __PACKAGE__->SKIP_CLASS("This test requires the $mod module");
            return;
        }
    }
}

sub _extra_path {
    my $cwd = cwd();

    return (
        $cwd->child(qw( node_modules .bin )),
        $cwd->child(qw( php5 usr bin )),
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

    return unless $self->require_executable( Code::TidyAll::Plugin::PerlCritic->_build_cmd );

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

    $file->spew_raw($source);

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
