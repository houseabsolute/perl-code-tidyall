package Code::TidyAll::Plugin::PerlTidy;
use Capture::Tiny qw(capture_merged);
use Perl::Tidy;
use Moo;
extends 'Code::TidyAll::Plugin';

sub transform_source {
    my ( $self, $source ) = @_;

    # perltidy reports errors in two different ways.
    # Argument/profile errors are output and an error_flag is returned.
    # Syntax errors are sent to errorfile.
    #
    my ( $output, $error_flag, $errorfile, $destination );
    $output = capture_merged {
        $error_flag = Perl::Tidy::perltidy(
            argv        => $self->argv,
            source      => \$source,
            destination => \$destination,
            errorfile   => \$errorfile
        );
    };
    die $errorfile       if $errorfile;
    die $output          if $error_flag;
    print STDERR $output if defined($output);
    return $destination;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::PerlTidy - use perltidy with tidyall

=head1 SYNOPSIS

   # In tidyall.ini:

   ; Configure in-line
   ;
   [PerlTidy]
   argv = --noll
   select = lib/**/*.pm

   ; or refer to a .perltidyrc in the same directory
   ;
   [PerlTidy]
   argv = --profile=$ROOT/.perltidyrc
   select = lib/**/*.pm

=head1 DESCRIPTION

Runs L<perltidy|perltidy>, a Perl tidier.

=head1 INSTALLATION

Install perltidy from CPAN.

    cpanm perltidy

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to perltidy

=back

