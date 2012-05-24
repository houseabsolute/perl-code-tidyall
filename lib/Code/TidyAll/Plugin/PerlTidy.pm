package Code::TidyAll::Plugin::perltidy;
use Hash::MoreUtils qw(slice_exists);
use Perl::Tidy;
use Moose;
extends 'Code::TidyAll::Plugin';

sub defaults {
    return { include => qr/\.(pl|pm|t)$/ };
}

sub process_source {
    my ( $self, $source ) = @_;
    my %params = slice_exists( $self->options, qw(argv prefilter postfilter) );
    Perl::Tidy::perltidy(
        %params,
        source      => \$source,
        destination => \my $destination,
        stderr      => \my $stderr,
    );
    die $stderr if $stderr;
    return $destination;
}

1;
