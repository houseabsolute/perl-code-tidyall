package Code::TidyAll::Test::Class;

use Capture::Tiny qw(capture_stdout);
use Code::TidyAll;
use Code::TidyAll::Util qw(dirname mkpath realpath tempdir_simple);
use File::Slurp::Tiny qw(read_file write_file);
use File::Which qw( which );
use Test::Class::Most;
use strict;
use warnings;

__PACKAGE__->SKIP_CLASS("abstract base class");

sub require_executable {
    my $self = shift;
    my $exe  = shift;

    which($exe)
        or $self->FAIL_ALL("These tests require that $exe be in your \$PATH");

    return;
}

sub create_dir {
    my ( $self, $files ) = @_;

    my $root_dir = tempdir_simple();
    while ( my ( $path, $content ) = each(%$files) ) {
        my $full_path = "$root_dir/$path";
        mkpath( dirname($full_path), 0, 0775 );
        write_file( $full_path, $content );
    }
    return realpath($root_dir);
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
        like( $output, $params{errors}, "$desc - errors" );
        ok( $error_count > 0, "$desc - error_count > 0" );
    }
    else {
        is( $error_count, 0, "$desc - error_count == 0" );
    }
    while ( my ( $path, $content ) = each( %{ $params{dest} } ) ) {
        is( read_file("$root_dir/$path"), $content, "$desc - $path content" );
    }
    if ( my $like_output = $params{like_output} ) {
        like( $output, $like_output, "$desc - output" );
    }
}

1;
