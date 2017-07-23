package Code::TidyAll::Plugin::JSHint;

use strict;
use warnings;

use IPC::Run3 qw(run3);
use Text::ParseWords qw(shellwords);

use Moo;

extends 'Code::TidyAll::Plugin';

has 'options' => ( is => 'ro', predicate => '_has_options' );

with 'Code::TidyAll::Role::Tempdir';

our $VERSION = '0.64';

sub _build_cmd {'jshint'}

sub validate_file {
    my ( $self, $file ) = @_;

    my @cmd = ( $self->cmd, shellwords( $self->argv ) );
    push @cmd, $self->_config_file_argv if $self->_has_options;
    push @cmd, $file;

    my $output;
    run3( \@cmd, \undef, \$output, \$output );
    if ( $output =~ /\S/ ) {
        $output =~ s/^$file:\s*//gm;
        die "$output\n";
    }
}

sub _config_file_argv {
    my $self = shift;

    my $conf_file = $self->_tempdir->child('jshint.json');
    $conf_file->spew(
        '{ ' . join( ",\n", map {qq["$_": true]} split /\s+/, $self->options ) . ' }' );
    return '--config', $conf_file;
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

=over

=item argv

Arguments to pass to jshint

=item cmd

Full path to jshint

=item options

A whitespace separated string of options, as documented
L<here|http://www.jshint.com/docs/>. These will be written to a temporary
config file and passed as --config to argv.

=back
