package Code::TidyAll::Plugin::PodTidy;

use strict;
use warnings;

use Capture::Tiny qw(capture_merged);
use Pod::Tidy;
use Specio::Library::Numeric;

use Moo;

extends 'Code::TidyAll::Plugin';

our $VERSION = '0.86';

has columns => (
    is  => 'ro',
    isa => t('PositiveInt'),
);

sub transform_file {
    my ( $self, $file ) = @_;

    my $output = capture_merged {
        Pod::Tidy::tidy_files(
            files    => [ $file->stringify ],
            inplace  => 1,
            nobackup => 1,
            verbose  => 1,
            ( $self->columns ? ( columns => $self->columns ) : () ),
        );
    };
    die $output if $output =~ /\S/ && $output !~ /does not contain Pod/;
}

1;

# ABSTRACT: Use podtidy with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [PodTidy]
   select = lib/**/*.{pm,pod}
   columns = 90

=head1 DESCRIPTION

Runs L<podtidy>, which will tidy the POD in your Perl or POD-only file.

=head1 INSTALLATION

Install podtidy from CPAN.

    cpanm podtidy

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 columns

Number of columns per line.

=cut
