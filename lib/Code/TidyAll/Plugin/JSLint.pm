package Code::TidyAll::Plugin::JSLint;

use IPC::Run3 qw(run3);
use Moo;
extends 'Code::TidyAll::Plugin';

our $VERSION = '0.47';

sub _build_cmd {'jslint'}

sub validate_file {
    my ( $self, $file ) = @_;

    my $cmd = sprintf( "%s %s %s", $self->cmd, $self->argv, $file );
    my $output;
    run3( $cmd, \undef, \$output, \$output );
    die "$output\n" if $output !~ /is OK\./;
}

1;

# ABSTRACT: Use jslint with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [JSLint]
   select = static/**/*.js
   argv = --white --vars --regex

=head1 DESCRIPTION

Runs L<jslint|http://www.jslint.com/>, a JavaScript validator, and dies if any
problems were found.

=head1 INSTALLATION

Install L<npm|https://npmjs.org/>, then run

    npm install jslint

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to jslint

=item cmd

Full path to jslint

=back
