package TestFor::Code::TidyAll::Plugin::PerlCritic;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $rc_file = $self->{root_dir}->child('perlcriticrc');
    $rc_file->spew("only = 1\nseverity = 1\n[TestingAndDebugging::RequireUseStrict]\n");

    $self->tidyall(
        source       => "my \$foo = 5\n",
        conf         => { argv => qq{--profile "$rc_file"} },
        expect_error => qr/Code before strictures/,
    );
    $self->tidyall(
        source    => "use strict;\nuse warnings;\nmy \$foo = 5\n",
        conf      => { argv => qq{--profile "$rc_file"} },
        expect_ok => 1,
    );
    $rc_file->spew("only = 1\nseverity = 1\n[CodeLayout::ProhibitHardTabs]\n");
    $self->tidyall(
        source    => "my \$foo = 5\n",
        conf      => { argv => qq{--profile "$rc_file"} },
        expect_ok => 1,
    );
    $self->tidyall(
        source       => "my \$foo = 5\n",
        conf         => { argv => qq{--profile "$rc_file" --badoption} },
        expect_error => qr/Unknown option: badoption/
    );
    $rc_file->spew("badconfig = 1\n");
    $self->tidyall(
        source       => "my \$foo = 5\n",
        conf         => { argv => qq{--profile "$rc_file"} },
        expect_error => qr/"badconfig" is not a supported option/
    );
}

1;
