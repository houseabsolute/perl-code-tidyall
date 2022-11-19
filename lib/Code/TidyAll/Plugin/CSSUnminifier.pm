package Code::TidyAll::Plugin::CSSUnminifier;

use strict;
use warnings;

use Moo;

extends 'Code::TidyAll::Plugin';

with 'Code::TidyAll::Role::RunsCommand';

our $VERSION = '0.84';

sub _build_cmd {'cssunminifier'}

sub transform_file {
    my ( $self, $file ) = @_;

    $self->_run_or_die( $file, $file );

    return;
}

1;

# ABSTACT: Use cssunminifier with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [CSSUnminifier]
   select = static/**/*.css
   argv = -w=2

=head1 DESCRIPTION

Runs L<cssunminifier|https://npmjs.org/package/cssunminifier>, a simple CSS
tidier.

=head1 INSTALLATION

Install L<npm|https://npmjs.org/>, then run

    npm install cssunminifier -g

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 argv

Arguments to pass to C<cssunminifier>.

=head2 cmd

The path for the C<cssunminifier> command. By default this is just
C<cssunminifier>, meaning that the user's C<PATH> will be searched for the
command.

=cut
