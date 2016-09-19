package Code::TidyAll::Plugin::PodTidy;

use Capture::Tiny qw(capture_merged);
use Pod::Tidy;
use Moo;
extends 'Code::TidyAll::Plugin';

our $VERSION = '0.52';

has 'columns' => ( is => 'ro' );

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

=over

=item columns

Number of columns per line

=back
