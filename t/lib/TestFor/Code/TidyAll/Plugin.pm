package TestFor::Code::TidyAll::Plugin;

use strict;
use warnings;
use autodie;

use Capture::Tiny qw(capture);
use Code::TidyAll::Util qw(pushd tempdir_simple);
use Code::TidyAll;
use Path::Tiny qw(path);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';
use Test::Differences qw( eq_or_diff );

__PACKAGE__->SKIP_CLASS("Virtual base class");

my $Test = Test::Builder->new;

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    $self->{root_dir} = tempdir_simple();
}

sub plugin_class {
    my ($self) = @_;

    return ( split( '::', ref($self) ) )[-1];
}

sub test_filename {'foo.txt'}

sub tidyall {
    my ( $self, %p ) = @_;

    my $extra = $self->_extra_path();
    local $ENV{PATH} = $ENV{PATH};
    $ENV{PATH} .= q{:} . $extra if $extra;

    my $plugin_class = $self->plugin_class;
    my %plugin_conf  = ( $plugin_class => { select => '*', %{ $p{conf} || {} } } );
    my $ct           = Code::TidyAll->new(
        quiet    => 1,
        root_dir => $self->{root_dir},
        plugins  => \%plugin_conf,
    );

    my ( $source, $result, $output, $error );
    if ( $p{source} ) {
        $source = $p{source};
        $source =~ s/\\n/\n/g;
        ( $output, $error ) = capture {
            $result = $ct->process_source( $source, $self->test_filename )
        };
    }
    elsif ( $p{source_file} ) {
        ( $output, $error )
            = capture { $result = $ct->process_file( $p{source_file} ) };
    }
    else {
        die 'The tidyall() method requires a source or source_file parameter';
    }

    my $desc = $p{desc} || $p{source} || $p{source_file};

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
            $source ||= path( $p{source_file} )->slurp;
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
