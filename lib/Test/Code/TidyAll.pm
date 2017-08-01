package Test::Code::TidyAll;

use strict;
use warnings;

use Code::TidyAll;
use List::Compare;
use Test::Builder;

# Text::Diff has to be loaded before ::Table
use Text::Diff;
use Text::Diff::Table;

use Exporter qw(import);

our $VERSION = '0.66';

my $test = Test::Builder->new;

our @EXPORT_OK = qw(tidyall_ok);
our @EXPORT    = @EXPORT_OK;

sub tidyall_ok {
    my %options   = @_;
    my $conf_file = delete( $options{conf_file} );
    if ( !$conf_file ) {
        my @conf_names = Code::TidyAll->default_conf_names;
        $conf_file = Code::TidyAll->find_conf_file( \@conf_names, "." );
    }
    $options{quiet} = 1 unless $options{verbose};
    $test->diag("Using $conf_file for config")
        if $options{verbose};

    my $files = delete $options{files};
    my $ct    = Code::TidyAll->new_from_conf_file(
        $conf_file,
        check_only    => 1,
        mode          => 'test',
        msg_outputter => \&_msg_outputter,
        %options,
    );

    my @files;
    if ($files) {
        @files = List::Compare->new( $files, [ $ct->find_matched_files ] )->get_intersection;
    }
    else {
        @files = $ct->find_matched_files;
    }

    unless (@files) {
        $test->plan( tests => 1 );
        $test->ok( 1, 'found no matching files for tidyall_ok' );
        return;
    }

    $test->plan( tests => scalar(@files) );
    foreach my $file (@files) {
        my $desc   = $ct->_small_path($file);
        my $result = $ct->process_file($file);
        $test->ok( $result->ok, "$desc is tidy" );
        unless ( $result->ok ) {
            $test->diag( $result->error );

            if ( $options{verbose} ) {
                my $orig = $result->orig_contents;
                my $new  = $result->new_contents;
                if ( defined $orig && defined $new ) {
                    $test->diag( diff( \$orig, \$new, { STYLE => 'Table' } ) );
                }
            }
        }
    }
}

sub _msg_outputter {
    my $format = shift;
    $test->diag( sprintf $format, @_ );
}

1;

# ABSTRACT: Check that all your files are tidy and valid according to tidyall

__END__

=pod

=head1 SYNOPSIS

  In a file like 't/tidyall.t':

    #!/usr/bin/perl
    use Test::Code::TidyAll;
    tidyall_ok();

=head1 DESCRIPTION

Uses L<Code::TidyAll>'s C<check_only> mode to check that all the files in your
project are in a tidied and valid state, i.e. that no plugins throw errors or
would change the contents of the file. Does not actually modify any files.

By default, we look for the config file C<tidyall.ini> or C<.tidyallrc> in the
current directory and parent directories, which is generally the right place if
you are running L<prove>.

When invoking L<Code::TidyAll>, we pass C<< mode => 'test' >> by default; see
L<modes|tidyall/MODES>.

=head1 EXPORTS

This module exports one subroutine, which is exported by default:

=head2 tidyall_ok(...)

Most options given to this subroutine will be passed along to the
L<Code::TidyAll> constructor. For example, if you don't want to use the tidyall
cache and instead check all files every time:

    tidyall_ok( no_cache => 1 );

or if you need to specify the config file:

    tidyall_ok( conf_file => '/path/to/conf/file' );

By default, this subroutine will test every file that matches the config you
specify. However, you can pass a C<files> parameter as an array reference to
override this, in which case only the files you specify will be tested. These
files are still filtered based on the C<select> and C<exclude> rules defined in
your config.

=head1 SEE ALSO

L<tidyall>

