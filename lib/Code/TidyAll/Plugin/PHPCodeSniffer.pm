package Code::TidyAll::Plugin::PHPCodeSniffer;

use strict;
use warnings;

use Moo;

extends 'Code::TidyAll::Plugin';

with 'Code::TidyAll::Role::RunsCommand';

our $VERSION = '0.79';

sub _build_cmd {'phpcs'}

sub validate_file {
    my ( $self, $file ) = @_;

    $self->_run_or_die($file);

    return;
}

1;

# ABSTRACT: Use phpcs with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [PHPCodeSniffer]
   select = htdocs/**/*.{php,js,css}
   cmd = /usr/local/pear/bin/phpcs
   argv = --severity 4

=head1 DESCRIPTION

Runs L<phpcs|http://pear.php.net/package/PHP_CodeSniffer> which analyzes PHP,
JavaScript and CSS files and detects violations of a defined set of coding
standards.

=head1 INSTALLATION

Install L<PEAR|http://pear.php.net/>, then install C<phpcs> from PEAR:

    pear install PHP_CodeSniffer

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 argv

Arguments to pass to C<phpcs>.

=head2 cmd

The path for the C<phpcs> command. By default this is just C<phpcs>, meaning
that the user's C<PATH> will be searched for the command.

=cut
