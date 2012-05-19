package Code::TidyAll::Plugin::PerlTidy;
use Moose;
extends 'Code::TidyAll::Plugin';

sub include_files { qr/\.(pl|pm|t)$/ }

sub process_source {
    my ( $self, $source ) = @_;
    my $conf = $self->conf;
    Perl::Tidy::perltidy(
        %$conf,
        source      => $source,
        destination => \my $destination,
        stderr      => \my $stderr,
    );
    die $stderr if $stderr;
    return $destination;
}

1;
