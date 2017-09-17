package TestFor::Code::TidyAll::Plugin::JSBeautify;

use Encode qw(encode);
use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

BEGIN {
    unless ( $ENV{TRAVIS} ) {
        require Test::Warnings;
        Test::Warnings->import('warnings');
    }
}

sub SKIP_CLASS {

    # For some reason running js-beautify fails under Travis for no reason I
    # can understand
    # (https://travis-ci.org/houseabsolute/perl-code-tidyall/jobs/276610909). I've
    # updating all the NPM modules. I've tried changing how the command is
    # called. I've tried a lot of things! But the test still passes locally,
    # so I'm giving up for now.
    return $ENV{TRAVIS} ? 'Running js-beautify fails under travis for some reason' : 0;
}

sub _extra_path {
    'node_modules/.bin';
}

sub test_main : Tests {
    my $self = shift;

    return unless $self->require_executable('node');
    return unless $self->require_executable('js-beautify');

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

    return unless $self->require_executable('node');
    return unless $self->require_executable('js-beautify');

    my $contents = encode( 'UTF-8', qq{var unicode  =  "Unicode - \x{263a}";} );
    my $expect   = encode( 'UTF-8', qq{var unicode = "Unicode - \x{263a}";} );

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

    my $file = $self->{root_dir}->child('test.js');
    $file->spew($contents);

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
