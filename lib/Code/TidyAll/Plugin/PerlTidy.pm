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
    my %params = slice_exists( $self->options, qw(argv prefilter postfilter) );

    no strict 'refs';
    &$perl_tidy_function(
        %params,
        source      => \$source,
        destination => \my $destination
    );
    return $destination;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::PerlTidy - use perltidy with tidyall

=head1 SYNOPSIS

   # In tidyall.ini:

   # Configure in-line
   #
   [Perltidy]
   argv = --noll
   select = lib/**/*.pm

   # or refer to a .perltidyrc in the same directory
   #
   [Perltidy]
   argv = --profile=$ROOT/.perltidyrc
   select = lib/**/*.pm

=head1 OPTIONS

=over

=item argv

Arguments to pass to C<perltidy>.

=item perl_tidy_class

Specify a C<Perl::Tidy> subclass to use instead of C<Perl::Tidy>.

=item prefilter, postfilter

Specify a prefilter and/or postfilter coderef. This can only be specified via
the L<Code::TidyAll|Code::TidyAll> module API.

=back
