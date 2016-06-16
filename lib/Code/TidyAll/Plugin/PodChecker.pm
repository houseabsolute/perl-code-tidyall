package Code::TidyAll::Plugin::PodChecker;

use Pod::Checker;
use Moo;
extends 'Code::TidyAll::Plugin';

our $VERSION = '0.49';

has 'warnings' => ( is => 'ro' );

sub validate_file {
    my ( $self, $file ) = @_;

    my $result;
    my %options = ( defined( $self->warnings ) ? ( '-warnings' => $self->warnings ) : () );
    my $checker = Pod::Checker->new(%options);
    my $output;
    open my $fh, '>', \$output;
    $checker->parse_from_file( $file, $fh );
    die $output
        if $checker->num_errors > 0
        || ( $self->warnings && $checker->num_warnings > 0 );
}

1;

# ABSTRACT: Use podchecker with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   ; Check for errors, but ignore warnings
   ;
   [PodChecker]
   select = lib/**/*.{pm,pod}

   ; Die on level 1 warnings (can also be set to 2)
   ;
   [PodChecker]
   select = lib/**/*.{pm,pod}
   warnings = 1

=head1 DESCRIPTION

Runs L<podchecker>, a POD validator, and dies if any problems were found.

=head1 INSTALLATION

Install podchecker from CPAN.

    cpanm podchecker

=head1 CONFIGURATION

=over

=item warnings

Level of warnings to consider as errors - 1 or 2. By default, warnings will be
ignored.

=back
