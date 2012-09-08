package Code::TidyAll::Plugin::JSHint;
use Capture::Tiny qw(capture_merged);
use Moo;
extends 'Code::TidyAll::Plugin';

sub _build_cmd { 'jshint' }

sub validate_file {
    my ( $self, $file ) = @_;

    my $cmd = sprintf( "%s %s %s", $self->cmd, $self->argv, $file );
    my $output = capture_merged { system($cmd) };
    die "$output\n" if $output =~ /\S/;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::JSHint - use jshint with tidyall

=head1 SYNOPSIS

   # In tidyall.ini:

   [JSHint]
   select = static/**/*.js
   argv = --config $ROOT/jshint.json

=head1 DESCRIPTION

This plugin requires you to install L<jshint|http://www.jshint.com/platforms/>.
The easiest way to do that at present time is to install
L<npm|https://npmjs.org/>, then run

    npm install jshint -g
