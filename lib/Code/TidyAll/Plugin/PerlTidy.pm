package Code::TidyAll::Plugin::PerlTidy;
use Code::TidyAll::Util qw(can_load);
use Hash::MoreUtils qw(slice_exists);
use strict;
use warnings;
use base qw(Code::TidyAll::Plugin);

sub process_source {
    my ( $self, $source ) = @_;
    my $options            = $self->options;
    my $perl_tidy_class    = $self->options->{perl_tidy_class} || 'Perl::Tidy';
    my $perl_tidy_function = $perl_tidy_class . "::perltidy";
    die "cannot load '$perl_tidy_class'" unless can_load($perl_tidy_class);

    # Determine parameters
    #
    my %params = slice_exists( $self->options, qw(argv prefilter postfilter perltidyrc) );

    no strict 'refs';
    &$perl_tidy_function(
        %params,
        source      => \$source,
        destination => \my $destination,
        stderr      => \my $stderr,
    );
    die $stderr if $stderr;
    return $destination;
}

1;
