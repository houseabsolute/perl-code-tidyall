package TestFor::Code::TidyAll::Plugin::PodTidy;

use Test::Class::Most parent => 'TestFor::Code::TidyAll::Plugin';

use Module::Runtime qw( require_module );
use Try::Tiny;

BEGIN {
    for my $mod (qw( Pod::Tidy )) {
        unless ( try { require_module($mod); 1 } ) {
            __PACKAGE__->SKIP_CLASS("This test requires the $mod module");
            return;
        }
    }
}

sub test_main : Tests {
    my $self = shift;

    my $source = '=head1 DESCRIPTION

There are a lot of great code tidiers and validators out there. C<tidyall> makes them available from a single unified interface.

You can run C<tidyall> on a single file or on an entire project hierarchy, and configure which tidiers/validators are applied to which files. C<tidyall> will back up files beforehand, and for efficiency will only consider files that have changed since they were last processed.

';
    $self->tidyall(
        source      => $source,
        expect_tidy => _maybe_crlf(
            '=head1 DESCRIPTION

There are a lot of great code tidiers and validators out there. C<tidyall>
makes them available from a single unified interface.

You can run C<tidyall> on a single file or on an entire project hierarchy, and
configure which tidiers/validators are applied to which files. C<tidyall> will
back up files beforehand, and for efficiency will only consider files that have
changed since they were last processed.

'
        ),
        desc => 'tidy - defaults',
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
        desc      => 'ok - defaults',
    );

    $self->tidyall(
        source      => $source,
        conf        => { columns => 30 },
        expect_tidy => _maybe_crlf(
            '=head1 DESCRIPTION

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
        ),
        desc => 'tidy - columns = 30',
    );
}

sub _maybe_crlf {
    return $_[0] unless $^O eq 'MSWin32';
    my $text = shift;
    $text =~ s/\n/\r\n/g;
    return $text;
}

1;
