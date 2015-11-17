package Test::Code::TidyAll;

use Code::TidyAll;
use Test::Builder;
use Text::Diff;
use Text::Diff::Table;
use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.32';

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
    my $ct = Code::TidyAll->new_from_conf_file(
        $conf_file,
        check_only    => 1,
        mode          => 'test',
        msg_outputter => \&_msg_outputter,
        %options,
    );
    my @files = $ct->find_matched_files;
    $test->plan( tests => scalar(@files) );
    foreach my $file (@files) {
        my $desc   = $ct->_small_path($file);
        my $result = $ct->process_file($file);
        if ( $result->ok ) {
            $test->ok( 1, $desc );
        }
        else {
            $test->ok( 0, $desc );
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

Uses L<tidyall --check-only|tidyall> to check that all the files in your
project are in a tidied and valid state, i.e. that no plugins throw errors or
would change the contents of the file. Does not actually modify any files.

By default, looks for config file C<tidyall.ini> or C<.tidyallrc> in the
current directory and parent directories, which is generally the right place if
you are running L<prove>.

Passes mode = "test" by default; see L<modes|tidyall/MODES>.

C<tidyall_ok> is exported by default. Any options will be passed along to the
L<Code::TidyAll> constructor. For example, if you don't want to use the tidyall
cache and instead check all files every time:

    tidyall_ok(no_cache => 1);

or if you need to specify the config file:

    tidyall_ok(conf_file => '/path/to/conf/file');

=head1 SEE ALSO

L<tidyall>

