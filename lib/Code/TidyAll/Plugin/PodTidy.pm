package Code::TidyAll::Plugin::PodTidy;
use Capture::Tiny qw(capture_merged);
use Hash::MoreUtils qw(slice_exists);
use Pod::Tidy;
use strict;
use warnings;
use base qw(Code::TidyAll::Plugin);

sub defaults {
    return { include => qr/\.(pl|pm|t)$/ };
}

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
    die $output if $output =~ /\S/;
}

1;
