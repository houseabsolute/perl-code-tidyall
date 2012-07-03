package Test::Code::TidyAll;
use IPC::System::Simple qw(run);
use Code::TidyAll;
use Test::Builder;
use strict;
use warnings;
use base qw(Exporter);

my $test = Test::Builder->new;

our @EXPORT_OK = qw(tidyall_ok);
our @EXPORT    = @EXPORT_OK;

sub tidyall_ok {
    my $conf_file = Code::TidyAll->find_conf_file(".");
    my $ct        = Code::TidyAll->new( check_only => 1, conf_file => $conf_file, @_ );
    my @files     = sort keys( %{ $ct->matched_files } );
    $test->plan( tests => scalar(@files) );
    foreach my $file (@files) {
        my $desc   = $ct->_small_path($file);
        my $result = $ct->process_file($file);
        if ( $result->ok ) {
            $test->ok( 1, $desc );
        }
        else {
            $test->diag( $result->msg );
            $test->ok( 0, $desc );
        }
    }
}

1;

__END__

=head1 NAME

Test::Code::TidyAll - check that all your files are tidy and valid according to
tidyall

=head1 SYNOPSIS

  In a file like 't/tidyall.t':

    #!/usr/bin/perl
    use Test::TidyAll;
    tidyall_ok();

=head1 DESCRIPTION

Uses L<tidyall --check-only|tidyall> to check that all the files in your
project are in a tidied and valid state, i.e. that no plugins throw errors or
would change the contents of the file. Does not actually modify any files.

By default, looks for config file C<tidyall.ini> in the current directory and
parent directories, which is generally the right place if you are running
L<prove|prove>.

C<tidyall_ok> is exported by default. Any options will be passed along to the
L<Code::TidyAll|Code::TidyAll> constructor. For example, if you don't want to
use the tidyall cache and instead check all files every time:

    run_tests(no_cache => 1);

or if you need to specify the config file:

    run_tests(conf_file => '/path/to/conf/file');

=head1 SEE ALSO

L<tidyall|tidyall>

