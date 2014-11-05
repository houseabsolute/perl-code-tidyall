package Test::Code::TidyAll::Plugin;

use Capture::Tiny qw(capture);
use Code::TidyAll::Util qw(tempdir_simple);
use Code::TidyAll;
use File::pushd;
use File::Path qw( mkpath );
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';
use Test::Differences qw( eq_or_diff );
use autodie;

__PACKAGE__->SKIP_CLASS("Virtual base class");

my $Test = Test::Builder->new;

sub startup : Tests(startup => no_plan) {
    my $self = shift;
    $self->{root_dir} = tempdir_simple();

    my $bin = 'node_modules/.bin';
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
        symlink $links{$from}, $from unless -l $from;
    }
}

sub plugin_class {
    my ($self) = @_;

    return ( split( '::', ref($self) ) )[-1];
}

sub test_filename { 'foo.txt' }

sub tidyall {
    my ( $self, %p ) = @_;

    my $extra = $self->_extra_path();
    local $ENV{PATH} = $ENV{PATH};
    $ENV{PATH} .= q{:} . $extra if $extra;

    my $source = $p{source} || die "source required";
    my $desc   = $p{desc}   || $source;
    $desc =~ s/\n/\\n/g;
    my $plugin_class = $self->plugin_class;
    my %plugin_conf = ( $plugin_class => { select => '*', %{ $p{conf} || {} } } );
    my $ct =
      Code::TidyAll->new( quiet => 1, root_dir => $self->{root_dir}, plugins => \%plugin_conf );

    $source =~ s/\\n/\n/g;
    my $result;
    my ( $output, $error ) =
      capture { $result = $ct->process_source( $source, $self->test_filename ) };
    $Test->diag($output) if $output && $ENV{TEST_VERBOSE};
    $Test->diag($error)  if $error  && $ENV{TEST_VERBOSE};

    if ( my $expect_tidy = $p{expect_tidy} ) {
        $expect_tidy =~ s/\\n/\n/g;
        is( $result->state, 'tidied', "state=tidied [$desc]" );
        eq_or_diff(
            $result->new_contents, $expect_tidy,
            "new contents [$desc]"
        );
        is( $result->error, undef, "no error [$desc]" );
    }
    elsif ( my $expect_ok = $p{expect_ok} ) {
        is( $result->state, 'checked', "state=checked [$desc]" );
        is( $result->error, undef,     "no error [$desc]" );
        if ( $result->new_contents ) {
            is( $result->new_contents, $source, "same contents [$desc]" );
        }
    }
    elsif ( my $expect_error = $p{expect_error} ) {
        is( $result->state, 'error', "state=error [$desc]" );
        like( $result->error || '', $expect_error, "error message [$desc]" );
    }
}

sub _extra_path {
    return;
}

1;
