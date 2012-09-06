package Code::TidyAll::Plugin::PodTidy;
use Capture::Tiny qw(capture_merged);
use Pod::Tidy;
use Moo;
extends 'Code::TidyAll::Plugin';

has 'columns' => ( is => 'ro' );

sub transform_file {
    my ( $self, $file ) = @_;

    my $output = capture_merged {
        Pod::Tidy::tidy_files(
            files    => [$file],
            inplace  => 1,
            nobackup => 1,
            verbose  => 1,
            ( $self->columns ? ( columns => $self->columns ) : () ),
        );
    };
    die $output if $output =~ /\S/ && $output !~ /does not contain Pod/;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::PodTidy - use podtidy with tidyall

=head1 SYNOPSIS

   # In tidyall.ini:

   [PodTidy]
   select = lib/**/*.{pm,pod}
   columns = 90

=head1 OPTIONS

=over

=item columns

Number of columns to fill

=back
