package Code::TidyAll::Util;
use File::Basename;
use File::Path;
use File::Slurp qw(read_file write_file);
use File::Temp qw(tempdir);
use Try::Tiny;
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(basename can_load dirname mkpath read_file tempdir_simple write_file );

sub can_load {

    # Load $class_name if possible. Return 1 if successful, 0 if it could not be
    # found, and rethrow load error (other than not found).
    #
    my ($class_name) = @_;

    my $result;
    try {
        eval "require $class_name";
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
    return tempdir( $template, TMPDIR => 1, CLEANUP => 1 );
}

1;
