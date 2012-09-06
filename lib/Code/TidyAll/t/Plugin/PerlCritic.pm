package Code::TidyAll::t::Plugin::PerlCritic;
use Code::TidyAll::Util qw(write_file);
use Test::Class::Most parent => 'Code::TidyAll::t::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $rc_file = $self->{root_dir} . "/perlcriticrc";

    write_file( $rc_file, "only = 1\nseverity = 1\n[TestingAndDebugging::RequireUseStrict]\n" );
    $self->tidyall(
        source       => 'my $foo = 5\n',
        conf         => { argv => "--profile $rc_file" },
        expect_error => qr/Code before strictures/,
    );
    $self->tidyall(
        source    => 'use strict;\nuse warnings;\nmy $foo = 5\n',
        conf      => { argv => "--profile $rc_file" },
        expect_ok => 1,
    );
    write_file( $rc_file, "only = 1\nseverity = 1\n[CodeLayout::ProhibitHardTabs]\n" );
    $self->tidyall(
        source    => 'my $foo = 5\n',
        conf      => { argv => "--profile $rc_file" },
        expect_ok => 1,
    );
}

1;
