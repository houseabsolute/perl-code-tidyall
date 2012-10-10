package Code::TidyAll::Plugin::HTMLTidy;
use Capture::Tiny qw(capture);
use Moo;
extends 'Code::TidyAll::Plugin';

sub _build_cmd { 'tidy' }

sub transform_file {
    my ( $self, $file ) = @_;

    my ( $output, $error ) =
      capture { system( sprintf( "%s -modify %s %s", $self->cmd, $self->argv, $file ) ) };
    die $error if $error;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::HTMLTidy - use HTML Tidy with tidyall

=head1 SYNOPSIS

   In configuration:

   [HTMLTidy]
   select = static/**/*.html
   argv = -i --indent-size 4 --show-warnings 0

=head1 DESCRIPTION

Runs L<HTML Tidy|http://tidy.sourceforge.net/>, the HTML tidier originally
created by Dave Raggett and now maintained on sourceforge.

Any warnings or errors will be deemed a validation failure. You can pass
"--show-warnings 0" and "--show-errors 0" to suppress warnings and errors
respectively.

=head1 INSTALLATION

Install the C<tidy> executable from the web site above if it is not already on
your system.

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to tidy. A comprehensive list of configuration options is
available at http://tidy.sourceforge.net/docs/quickref.html.

=item cmd

Full path to tidy

=back
