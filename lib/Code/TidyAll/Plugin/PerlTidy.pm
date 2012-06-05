package Code::TidyAll::Plugin::PerlTidy;
use Hash::MoreUtils qw(slice_exists);
use Perl::Tidy;
use strict;
use warnings;
use base qw(Code::TidyAll::Plugin);

sub defaults {
    return { include => qr/\.(pl|pm|t)$/ };
}

sub process_source {
    my ( $self, $source ) = @_;
    my $options = $self->options;

    # Determine parameters
    #
    my %params = slice_exists( $self->options, qw(argv prefilter postfilter perltidyrc) );

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
