package Code::TidyAll::Plugin::JSHint;

use strict;
use warnings;

use Specio::Library::String;

use Moo;

extends 'Code::TidyAll::Plugin';

has options => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_options',
);

with qw( Code::TidyAll::Role::RunsCommand Code::TidyAll::Role::Tempdir );

our $VERSION = '0.84';

sub _build_cmd {'jshint'}

sub validate_file {
    my ( $self, $file ) = @_;

    my $output = $self->_run_or_die( $self->_config_file_argv, $file );
    if ( $output =~ /\S/ ) {
        $output =~ s/^$file:\s*//gm;
        die "$output\n";
    }

    return;
}

sub _config_file_argv {
    my $self = shift;

    return unless $self->_has_options;

    my $conf_file = $self->_tempdir->child('jshint.json');
    $conf_file->spew(
        '{ ' . join( ",\n", map {qq["$_": true]} split /\s+/, $self->options ) . ' }' );

    return ( '--config', $conf_file );
}

1;

# ABSTRACT: Use jshint with tidyall

__END__

=pod

=head1 SYNOPSIS

   In configuration:

   ; With default settings
   ;
   [JSHint]
   select = static/**/*.js

   ; Specify options inline
   ;
   [JSHint]
   select = static/**/*.js
   options = bitwise camelcase latedef

   ; or refer to a jshint.json config file in the same directory
   ;
   [JSHint]
   select = static/**/*.js
   argv = --config $ROOT/jshint.json

   where jshint.json looks like

   {
      "bitwise": true,
      "camelcase": true,
      "latedef": true
   }

=head1 DESCRIPTION

Runs L<jshint|http://www.jshint.com/>, a JavaScript validator, and dies if any
problems were found.

=head1 INSTALLATION

See installation options at L<jshint|http://www.jshint.com/platforms/>. One
easy method is to install L<npm|https://npmjs.org/>, then run

    npm install jshint -g

=head1 CONFIGURATION

This plugin accepts the following configuration options:

=head2 argv

Arguments to pass to C<jshint>.

=head2 cmd

The path for the C<jshint> command. By default this is just C<jshint>, meaning
that the user's C<PATH> will be searched for the command.

=head2 options

A whitespace separated string of options, as L<documented by
jshint|http://www.jshint.com/docs/>. These will be written to a temporary
config file and passed as C<--config> argument.

=cut
