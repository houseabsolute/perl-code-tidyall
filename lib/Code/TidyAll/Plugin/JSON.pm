package Code::TidyAll::Plugin::JSON;

use strict;
use warnings;

use JSON ();
use Moo;

extends 'Code::TidyAll::Plugin';

has 'ascii' => ( is => 'ro', default => sub { 0 } );

sub transform_source {
    my $self   = shift;
    my $source = shift;

    my $json = JSON->new->relaxed->pretty->canonical;

    $json = $json->ascii if $self->ascii;

    return $json->encode( $json->decode($source) );
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::JSON - use the JSON module with tidyall

=head1 SYNOPSIS

   In configuration:

   [JSON]
   select = **/*.json
   ascii = 1

=head1 DESCRIPTION

Uses L<JSON> to format JSON files. Files are put into a canonical format
with the keys of objects sorted.

=head1 CONFIGURATION

=over

=item ascii

Escape non-ASCII characters. The output file will be valid ASCII.

=back
