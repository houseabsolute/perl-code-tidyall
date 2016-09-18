package Code::TidyAll::Util;

use Guard;
use Path::Tiny qw(cwd tempdir);
use Try::Tiny;
use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.51';

our @EXPORT_OK = qw(can_load pushd tempdir_simple);

sub can_load {

    # Load $class_name if possible. Return 1 if successful, 0 if it could not be
    # found, and rethrow load error (other than not found).
    #
    my ($class_name) = @_;

    my $result;
    try {
        eval "require $class_name";    ## no critic
        die $@ if $@;
        $result = 1;
    }
    catch {
        if ( /Can\'t locate .* in \@INC/ && !/Compilation failed/ ) {
            $result = 0;
        }
        else {
            die $_;
        }
    };
    return $result;
}

sub tempdir_simple {
    my $template = shift || 'Code-TidyAll-XXXX';
    return tempdir( $template, CLEANUP => 1 );
}

sub pushd {
    my ($dir) = @_;

    my $cwd = cwd();
    chdir($dir);
    return guard { chdir($cwd) };
}

1;
