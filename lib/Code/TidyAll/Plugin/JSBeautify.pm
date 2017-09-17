package Code::TidyAll::Plugin::JSBeautify;

use strict;
use warnings;

use IPC::Run3 qw(run3);
use Text::ParseWords qw(shellwords);
use Try::Tiny;

use Moo;

extends 'Code::TidyAll::Plugin';

with 'Code::TidyAll::Role::RunsCommand';

our $VERSION = '0.67';

sub _build_cmd {'js-beautify'}

sub transform_file {
    my ( $self, $file ) = @_;

    my $output = $self->_run_or_die( '-f', $file );
    $file->spew($output);

    return;
}

1;

# ABSTRACT: Use js-beautify with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   [JSBeautify]
   select = static/**/*.js
   argv = --indent-size 2 --brace-style expand

=head1 DESCRIPTION

Runs L<js-beautify|https://npmjs.org/package/js-beautify>, a JavaScript tidier.

=head1 INSTALLATION

Install L<npm|https://npmjs.org/>, then run

    npm install js-beautify -g

Do not confuse this with the C<jsbeautify> command, which is provided by the
L<JavaScript::Beautifier> module.

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 argv

Arguments to pass to C<js-beautify>.

=head2 cmd

The path for the C<js-beautify> command. By default this is just
C<js-beautify>, meaning that the user's C<PATH> will be searched for the
command.

