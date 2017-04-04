package Code::TidyAll::Plugin::JSBeautifier;

use File::Slurp::Tiny qw(write_file);
use IPC::Run3 qw(run3);
use Moo;
use Try::Tiny;
extends 'Code::TidyAll::Plugin';

our $VERSION = '0.33';

sub _build_cmd {'js_beautify.pl'}

sub transform_file {
    my ( $self, $file ) = @_;

    try {
        my $cmd = join( " ", $self->cmd, '-o', $self->argv, $file );

        my $output;
        run3( $cmd, \undef, \$output, \$output );
        #write_file( $file, $output );
    }
    catch {
        die sprintf(
            "%s exited with error - possibly bad arg list '%s'\n    $_", $self->cmd,
            $self->argv
        );
    };
}

1;

# ABSTRACT: Use JavaScript::Beautifier with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [JSBeautifier]
   select = static/**/*.js

https://metacpan.org/pod/JavaScript::Beautifier

=head1 DESCRIPTION

Runs C<js_beautify.pl> of L<JavaScript::Beautifier>, a JavaScript tidier implemented in Perl.

=head1 INSTALLATION

    cpanm JavaScript::Beautifier

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to js_beautify.pl

=item cmd

Full path to js_beautify.pl

=back
