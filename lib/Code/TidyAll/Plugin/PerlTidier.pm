package Code::TidyAll::Plugin::PerlTidier;
use Capture::Tiny qw(capture_merged);
use Perl::Tidy::Sweetened;
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
        $error_flag = Perl::Tidy::Sweetened::perltidy(
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

Code::TidyAll::Plugin::PerlTidier - use perltidier with tidyall

=head1 SYNOPSIS

   # In configuration:

   ; Configure in-line
   ;
   [PerlTidier]
   select = lib/**/*.pm
   argv = --noll

   ; or refer to a .perltidyrc in the same directory
   ;
   [PerlTidier]
   select = lib/**/*.pm
   argv = --profile=$ROOT/.perltidyrc

=head1 DESCRIPTION

Runs L<perltidier|perltider>, a Perl tidier based on Perl::Tidy that also
supports new syntactic sugar as provided by L<Method::Signature::Simple>,
L<MooseX::Method::Signatures> and the p5-mop.

=head1 INSTALLATION

Install perltidier from CPAN.

    cpanm Perl::Tidy::Sweetened

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to perltidier

=back

