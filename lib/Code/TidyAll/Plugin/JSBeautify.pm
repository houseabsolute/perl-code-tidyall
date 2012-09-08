package Code::TidyAll::Plugin::JSBeautify;
use IPC::System::Simple qw(run);
use Moo;
extends 'Code::TidyAll::Plugin';

sub _build_cmd { 'js-beautify' }

sub transform_file {
    my ( $self, $file ) = @_;

    run( sprintf( "%s --replace %s %s", $self->cmd, $self->argv, $file ) );
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::JSBeautify - use jsbeautify with tidyall

=head1 SYNOPSIS

   # In tidyall.ini:

   [JSBeautify]
   select = static/**/*.js
   argv = --indent-size 2 --brace-style expand

=head1 INSTALLATION

This plugin requires you to install the
L<js-beautify|https://npmjs.org/package/js-beautify> npm package. Install
L<npm|https://npmjs.org/>, then run

    npm install js-beautfy -g

Do not confuse this with the C<jsbeautify> package (without the dash).

