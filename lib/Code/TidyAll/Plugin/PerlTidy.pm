package Code::TidyAll::Plugin::PerlTidy;
use Perl::Tidy;
use Moo;
extends 'Code::TidyAll::Plugin';

sub transform_source {
    my ( $self, $source ) = @_;

    my $errorfile;
    no strict 'refs';
    Perl::Tidy::perltidy(
        argv        => $self->argv,
        source      => \$source,
        destination => \my $destination,
        errorfile   => \$errorfile
    );
    die $errorfile if $errorfile;
    return $destination;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::PerlTidy - use perltidy with tidyall

=head1 SYNOPSIS

   # In tidyall.ini:

   # Configure in-line
   #
   [PerlTidy]
   argv = --noll
   select = lib/**/*.pm

   # or refer to a .perltidyrc in the same directory
   #
   [PerlTidy]
   argv = --profile=$ROOT/.perltidyrc
   select = lib/**/*.pm
