package Code::TidyAll::Plugin::PodChecker;

use strict;
use warnings;

use Pod::Checker;
use Specio::Library::Numeric;

use Moo;

extends 'Code::TidyAll::Plugin';

our $VERSION = '0.78';

has warnings => (
    is  => 'ro',
    isa => t('PositiveInt'),
);

sub validate_file {
    my ( $self, $file ) = @_;

    my $result;
    my %options = ( $self->warnings ? ( '-warnings' => $self->warnings ) : () );
    my $checker = Pod::Checker->new(%options);
    my $output;
    open my $fh, '>', \$output;
    $checker->parse_from_file( $file->stringify, $fh );
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

This plugin accepts the following configuration options:

=head2 warnings

The level of warnings to consider as errors - 1 or 2. By default, warnings will
be ignored.

=cut
