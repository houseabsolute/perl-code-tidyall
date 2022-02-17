package Code::TidyAll::Plugin::PerlTidy;

use strict;
use warnings;

use Capture::Tiny qw(capture_merged);
use Perl::Tidy;

use Moo;

extends 'Code::TidyAll::Plugin';

our $VERSION = '0.81';

sub transform_source {
    my ( $self, $source ) = @_;

    # This bit of insanity is needed because if some other code calls
    # Getopt::Long::Configure() to change some options, then everything can go
    # to hell. Internally perltidy() tries to use Getopt::Long without
    # resetting the configuration defaults, leading to very confusing
    # errors. See https://rt.cpan.org/Ticket/Display.html?id=118558
    Getopt::Long::ConfigDefaults();

    # perltidy reports errors in two different ways.
    # Argument/profile errors are output and an error_flag is returned.
    # Syntax errors are sent to errorfile or stderr, depending on the
    # the setting of -se/-nse (aka --standard-error-output).  These flags
    # might be hidden in other bundles, e.g. -pbp.  Be defensive and
    # check both.
    my ( $output, $error_flag, $errorfile, $stderr, $destination );

    # Add --encode-output-strings (-eos) for PT releases in 2022 and later to
    # tell perltidy that we want encoded character strings returned.  See
    # https://github.com/houseabsolute/perl-code-tidyall/issues/84
    # https://github.com/perltidy/perltidy/issues/83
    my $argv = $self->argv;
    $argv .= ' --encode-output-strings' if $Perl::Tidy::VERSION > 20220101;

    $output = capture_merged {
        $error_flag = Perl::Tidy::perltidy(
            argv        => $self->argv,
            source      => \$source,
            destination => \$destination,
            stderr      => \$stderr,
            errorfile   => \$errorfile
        );
    };
    die $stderr          if $stderr;
    die $errorfile       if $errorfile;
    die $output          if $error_flag;
    print STDERR $output if defined($output);
    return $destination;
}

1;

# ABSTRACT: Use perltidy with tidyall

__END__

=pod

=head1 SYNOPSIS

   # In configuration:

   ; Configure in-line
   ;
   [PerlTidy]
   select = lib/**/*.pm
   argv = --noll

   ; or refer to a .perltidyrc in the same directory
   ;
   [PerlTidy]
   select = lib/**/*.pm
   argv = --profile=$ROOT/.perltidyrc

=head1 DESCRIPTION

Runs L<perltidy>, a Perl tidier.

=head1 INSTALLATION

Install perltidy from CPAN.

    cpanm perltidy

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 argv

Arguments to pass to C<perltidy>.

If you are using C<Perl::Tidy> version 20220101 or newer, than the
C<--encode-output-strings> flag will be appended to whatever you supply. In
this case, you should ensure that you are I<not> passing a
C<--character-encoding> (C<-enc>) or C<-utf8> flag to perltidy as well.
