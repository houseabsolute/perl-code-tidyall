package Code::TidyAll::Plugin::PerlTidy;
use Perl::Tidy;
use Hash::MoreUtils qw(slice_exists);
use strict;
use warnings;
use base qw(Code::TidyAll::Plugin);

sub process_source {
    my ( $self, $source ) = @_;
    my $options = $self->options;

    # Determine parameters
    #
    my %params = slice_exists( $self->options, qw(argv) );

    my $errorfile;
    no strict 'refs';
    Perl::Tidy::perltidy(
        %params,
        source      => \$source,
        destination => \my $destination,
        errorfile   => \$errorfile
    );
    die $errorfile if $errorfile;
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

=back
