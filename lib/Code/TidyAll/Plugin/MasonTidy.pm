package Code::TidyAll::Plugin::MasonTidy;

use strict;
use warnings;

use Mason::Tidy::App;
use Text::ParseWords qw(shellwords);

use Moo;

extends 'Code::TidyAll::Plugin';

our $VERSION = '0.82';

sub _build_cmd {'masontidy'}

sub transform_source {
    my ( $self, $source ) = @_;

    local @ARGV = shellwords( $self->argv );
    local $ENV{MASONTIDY_OPT};
    my $dest = Mason::Tidy::App->run($source);
    return $dest;
}

1;

# ABSTRACT: Use masontidy with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [MasonTidy]
   select = comps/**/*.{mc,mi}
   argv = --indent-perl-block 0 --perltidy-argv "-noll -l=78"

=head1 DESCRIPTION

Runs L<masontidy>, a tidier for L<HTML::Mason> and L<Mason 2|Mason> components.

=head1 INSTALLATION

Install L<masontidy> from CPAN.

    cpanm masontidy

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 argv

Arguments to pass to C<masontidy>.

