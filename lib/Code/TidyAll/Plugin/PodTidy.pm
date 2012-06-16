package Code::TidyAll::Plugin::PodTidy;
use Capture::Tiny qw(capture_merged);
use Hash::MoreUtils qw(slice_exists);
use Pod::Tidy;
use strict;
use warnings;
use base qw(Code::TidyAll::Plugin);

sub process_file {
    my ( $self, $file ) = @_;
    my $options = $self->options;

    my %params = slice_exists( $self->options, qw(columns) );
    my $output = capture_merged {
        Pod::Tidy::tidy_files(
            %params,
            files    => [$file],
            inplace  => 1,
            nobackup => 1,
            verbose  => 1,
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
   argv = --column=90
   select = lib/**/*.{pm,pod}

=head1 OPTIONS

=over

=item argv

Arguments to pass to podtidy.

=back
