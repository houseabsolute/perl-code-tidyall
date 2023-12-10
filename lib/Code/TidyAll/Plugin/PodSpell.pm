package Code::TidyAll::Plugin::PodSpell;

use strict;
use warnings;

use Capture::Tiny qw();
use IPC::Run3     qw(run3);
use Pod::Spell;
use Specio::Library::Builtins;
use Specio::Library::String;
use Text::ParseWords qw(shellwords);

use Moo;

extends 'Code::TidyAll::Plugin';

our $VERSION = '0.85';

has ispell_argv => (
    is      => 'ro',
    isa     => t('Str'),
    default => q{}
);

has ispell_cmd => (
    is      => 'ro',
    isa     => t('NonEmptyStr'),
    default => 'ispell'
);

has suggest => (
    is  => 'ro',
    isa => t('Bool'),
);

sub validate_file {
    my ( $self, $file ) = @_;

    my ( $text, $error )
        = Capture::Tiny::capture { Pod::Spell->new->parse_from_file( $file->stringify ) };
    die $error if $error;

    my ($output);
    my @cmd = ( $self->ispell_cmd, shellwords( $self->ispell_argv ), '-a' );
    eval { run3( \@cmd, \$text, \$output, \$error ) };
    $error = $@                                                  if $@;
    die q{error running '} . join( ' ', @cmd ) . q{': } . $error if $error;

    my ( @errors, %seen );
    foreach my $line ( split( "\n", $output ) ) {
        if ( my ( $original, $remaining ) = ( $line =~ /^[\&\?\#] (\S+)\s+(.*)/ ) ) {
            if ( !$seen{$original}++ ) {
                my ($suggestions) = ( $remaining =~ /: (.*)/ );
                if ( $suggestions && $self->suggest ) {
                    push( @errors, sprintf( '%s (suggestions: %s)', $original, $suggestions ) );
                }
                else {
                    push( @errors, $original );
                }
            }
        }
    }
    die sprintf( "unrecognized words:\n%s\n", join( "\n", sort @errors ) ) if @errors;
}

1;

# ABSTRACT: Use Pod::Spell + ispell with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [PodSpell]
   select = lib/**/*.{pm,pod}
   ispell_argv = -p $ROOT/.ispell_english
   suggest = 1

=head1 DESCRIPTION

Uses L<Pod::Spell> in combination with
L<ispell|http://fmg-www.cs.ucla.edu/geoff/ispell.html> to spell-check POD. Any
seemingly misspelled words will be output one per line.

You can specify additional valid words by:

=over

=item *

Adding them to your personal ispell dictionary, e.g. ~/.ispell_english

=item *

Adding them to an ispell dictionary in the project root, then including this in
the configuration:

    ispell_argv = -p $ROOT/.ispell_english

=back

The dictionary file should contain one word per line.

=head1 INSTALLATION

Install ispell from your package manager or from the link above.

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 ispell_argv

Arguments to pass to ispell. The "-a" flag will always be passed, in order to
parse the results.

=head2 ispell_cmd

The path for the C<ispell> command. By default this is just C<ispell>, meaning
that the user's C<PATH> will be searched for the command.

=head2 suggest

If true, show suggestions next to misspelled words. Default is false.

=cut
