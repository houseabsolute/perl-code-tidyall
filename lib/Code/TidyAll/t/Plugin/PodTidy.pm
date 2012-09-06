package Code::TidyAll::t::Plugin::PodTidy;
use Test::Class::Most parent => 'Code::TidyAll::t::Plugin';

sub test_main : Tests {
    my $self = shift;

    my $source = '=head1 DESCRIPTION

There are a lot of great code tidiers and validators out there. C<tidyall> makes them available from a single unified interface.

You can run C<tidyall> on a single file or on an entire project hierarchy, and configure which tidiers/validators are applied to which files. C<tidyall> will back up files beforehand, and for efficiency will only consider files that have changed since they were last processed.

';
    $self->tidyall(
        source      => $source,
        expect_tidy => '=head1 DESCRIPTION

There are a lot of great code tidiers and validators out there. C<tidyall>
makes them available from a single unified interface.

You can run C<tidyall> on a single file or on an entire project hierarchy, and
configure which tidiers/validators are applied to which files. C<tidyall> will
back up files beforehand, and for efficiency will only consider files that have
changed since they were last processed.

'
    );

    $self->tidyall(
        source => '=head1 DESCRIPTION

There are a lot of great code tidiers and validators out there. C<tidyall>
makes them available from a single unified interface.

You can run C<tidyall> on a single file or on an entire project hierarchy, and
configure which tidiers/validators are applied to which files. C<tidyall> will
back up files beforehand, and for efficiency will only consider files that have
changed since they were last processed.

',
        expect_ok => 1,
    );

    $self->tidyall(
        source      => $source,
        conf        => { columns => 30 },
        expect_tidy => '=head1 DESCRIPTION

There are a lot of great code
tidiers and validators out
there. C<tidyall> makes them
available from a single
unified interface.

You can run C<tidyall> on a
single file or on an entire
project hierarchy, and
configure which
tidiers/validators are
applied to which files.
C<tidyall> will back up files
beforehand, and for
efficiency will only consider
files that have changed since
they were last processed.

'
    );
}

1;
