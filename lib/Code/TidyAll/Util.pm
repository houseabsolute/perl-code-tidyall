package Code::TidyAll::Util;
use Cwd qw(realpath);
use Data::Dumper;
use File::Basename;
use File::Path;
use File::pushd qw(pushd);
use File::Slurp qw(read_file write_file read_dir);
use File::Spec::Functions qw(abs2rel rel2abs);
use File::Temp qw(tempdir);
use List::MoreUtils qw(uniq);
use Try::Tiny;
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK =
  qw(abs2rel basename can_load dirname dump_one_line mkpath pushd read_dir read_file realpath rel2abs tempdir_simple uniq write_file );

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
    return realpath( tempdir( $template, TMPDIR => 1, CLEANUP => 0 ) );
}

sub dump_one_line {
    my ($value) = @_;

    return Data::Dumper->new( [$value] )->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(1)->Dump();
}

1;
