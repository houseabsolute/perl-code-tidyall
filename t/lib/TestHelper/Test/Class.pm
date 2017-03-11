package TestHelper::Test::Class;

use Capture::Tiny qw(capture_stdout);
use Code::TidyAll;
use Code::TidyAll::Util qw(tempdir_simple);
use File::Which qw(which);
use Test::Class::Most;
use strict;
use warnings;

__PACKAGE__->SKIP_CLASS("abstract base class");

sub require_executable {
    my $self = shift;
    my $exe  = shift;

    return 1 if which($exe);

    $self->builder->skip("These tests require that $exe be in your \$PATH");

    return 0;
}

sub create_dir {
    my ( $self, $files ) = @_;

    my $root_dir = tempdir_simple();
    while ( my ( $path, $content ) = each(%$files) ) {
        my $full_path = $root_dir->child($path);
        $full_path->parent->mkpath( { mode => 0755 } );
        $full_path->spew($content);
    }
    return $root_dir;
}

sub tidy {
    my ( $self, %params ) = @_;
    my $desc = $params{desc};
    if ( !defined($desc) ) {
        ($desc) = ( ( caller(1) )[3] =~ /([^:]+$)/ );
    }

    my $root_dir = $self->create_dir( $params{source} );

    my $options = $params{options} || {};
    my $ct = Code::TidyAll->new(
        plugins  => $params{plugins},
        root_dir => $root_dir,
        %$options
    );

    my @results;
    my $output = capture_stdout { @results = $ct->process_all() };
    my $error_count = grep { $_->error } @results;
    if ( $params{errors} ) {
        ok( $error_count > 0, "$desc - error_count > 0" );
        if ( eval { @{ $params{errors} } } ) {
            like( $output, $_, "$desc - errors" ) for @{ $params{errors} };
        }
        else {
            like( $output, $params{errors}, "$desc - errors" );
        }
    }
    else {
        is( $error_count, 0, "$desc - error_count == 0" );
    }
    while ( my ( $path, $content ) = each( %{ $params{dest} } ) ) {
        is( $root_dir->child($path)->slurp, $content, "$desc - $path content" );
    }
    if ( my $like_output = $params{like_output} ) {
        like( $output, $like_output, "$desc - output" );
    }
}

1;
