package Code::TidyAll::Plugin::PHPCodeSniffer;
use Capture::Tiny qw(capture_merged);
use Moo;
extends 'Code::TidyAll::Plugin';

sub _build_cmd { 'phpcs' }

sub validate_file {
    my ( $self, $file ) = @_;

    my $cmd = sprintf( "%s %s %s", $self->cmd, $self->argv, $file );
    my $output = capture_merged { system($cmd) };
    die "$output\n" if $output !~ /^.* source OK\n/;
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::PHPCodeSniffer - use phpcs with tidyall

=head1 VERSION

version 0.15

=head1 SYNOPSIS

   In configuration:

   ; Configure in-line
   ;
   [PHPCodeSniffer]
   select = /my/project/**/*.php
   argv = --standard=/my/project/phpcs.xml --ignore=*/tests/*,*/data/*

=head1 DESCRIPTION

Runs L<phpcs|http://pear.php.net/package/PHP_CodeSniffer> which tokenises PHP,
JavaScript and CSS files and detects violations of a defined set of coding
standards.

=head1 INSTALLATION

Install phpcs from PEAR.

    pear install PHP_CodeSniffer

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to phpcs

=back
