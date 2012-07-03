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
    my $ct        = Code::TidyAll->new( check_only => 1, conf_file => $conf_file );
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
