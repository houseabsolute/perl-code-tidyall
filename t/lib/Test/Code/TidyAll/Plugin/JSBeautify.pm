package Test::Code::TidyAll::Plugin::JSBeautify;

use Encode qw(encode);
use File::Slurp::Tiny qw(write_file);
use Test::Class::Most parent => 'Test::Code::TidyAll::Plugin';
use Test::Warnings qw(warnings);

sub _extra_path {
    'node_modules/.bin';
}

sub test_main : Tests {
    my $self = shift;

    $self->require_executable('node');

    my $source = 'sp.toggleResult=function(id){foo(id)}';
    $self->tidyall(
        source      => $source,
        expect_tidy => 'sp.toggleResult = function(id) {\n    foo(id)\n}',
    );
    $self->tidyall(
        source      => $source,
        conf        => { argv => '--indent-size 3 --brace-style expand' },
        expect_tidy => 'sp.toggleResult = function(id)\n{\n   foo(id)\n}',
    );
}

sub test_utf8 : Tests {
    my $self = shift;

    my $contents
        = encode( 'UTF-8', qq{var unicode  =  "Unicode - \x{263a}";} );
    my $expect = encode( 'UTF-8', qq{var unicode = "Unicode - \x{263a}";} );

    local $SIG{__WARN__} = sub { Carp::cluck(@_) };
    is_deeply(
        [
            warnings {
                $self->tidyall(
                    source      => $contents,
                    expect_tidy => $expect,
                    desc        => 'tidy UTF-8 from string',
                );
            }
        ],
        [],
        'no warnings tidying UTF-8 source'
    );

    my $file = $self->{root_dir} . '/test.js';
    write_file( $file, $contents );

    is_deeply(
        [
            warnings {
                $self->tidyall(
                    source_file => $file,
                    expect_tidy => $expect,
                    desc        => 'tidy UTF-8 from file',
                );
            }
        ],
        [],
        'no warnings tidying UTF-8 source'
    );
}

1;
