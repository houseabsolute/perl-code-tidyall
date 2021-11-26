# This is a copy of Text::Glob, modified to support "**/"
#
package Code::TidyAll::Util::Zglob;

use strict;
use warnings;

our $VERSION = '0.79';

use Exporter qw(import);

our @EXPORT_OK = qw( zglobs_to_regex zglob_to_regex );

our $strict_leading_dot    = 1;
our $strict_wildcard_slash = 1;

use constant debug => 0;

sub zglobs_to_regex {
    my @globs = @_;
    return @globs
        ? do {
        my $re = join( '|', map { "(?:" . zglob_to_regex($_) . ")" } @globs );
        qr/$re/;
        }
        : qr/(?!)/;
}

sub zglob_to_regex {
    my $glob  = shift;
    my $regex = zglob_to_regex_string($glob);
    return qr/^$regex$/;
}

sub zglob_to_regex_string {
    my $glob = shift;
    my ( $regex, $in_curlies, $escaping );
    local $_;
    my $first_byte = 1;
    $glob =~ s/\*\*\//\cZ/g;    # convert **/ to single character
    for ( $glob =~ m/(.)/gs ) {
        if ($first_byte) {
            if ($strict_leading_dot) {
                $regex .= '(?=[^\.])' unless $_ eq '.';
            }
            $first_byte = 0;
        }
        if ( $_ eq '/' ) {
            $first_byte = 1;
        }
        if (   $_ eq '.'
            || $_ eq '('
            || $_ eq ')'
            || $_ eq '|'
            || $_ eq '+'
            || $_ eq '^'
            || $_ eq '$'
            || $_ eq '@'
            || $_ eq '%' ) {
            $regex .= "\\$_";
        }
        elsif ( $_ eq "\cZ" ) {    # handle **/ - if escaping, only escape first *
            $regex
                .= $escaping
                ? ( "\\*" . ( $strict_wildcard_slash ? "[^/]*" : ".*" ) . "/" )
                : ".*";
        }
        elsif ( $_ eq '*' ) {
            $regex
                .= $escaping             ? "\\*"
                : $strict_wildcard_slash ? "[^/]*"
                :                          ".*";
        }
        elsif ( $_ eq '?' ) {
            $regex
                .= $escaping             ? "\\?"
                : $strict_wildcard_slash ? "[^/]"
                :                          ".";
        }
        elsif ( $_ eq '{' ) {
            $regex .= $escaping ? "\\{" : "(";
            ++$in_curlies unless $escaping;
        }
        elsif ( $_ eq '}' && $in_curlies ) {
            $regex .= $escaping ? "}" : ")";
            --$in_curlies unless $escaping;
        }
        elsif ( $_ eq ',' && $in_curlies ) {
            $regex .= $escaping ? "," : "|";
        }
        elsif ( $_ eq "\\" ) {
            if ($escaping) {
                $regex .= "\\\\";
                $escaping = 0;
            }
            else {
                $escaping = 1;
            }
            next;
        }
        else {
            $regex .= $_;
            $escaping = 0;
        }
        $escaping = 0;
    }
    print "# $glob $regex\n" if debug;

    return $regex;
}

1;

# ABSTRACT: Test::Glob hacked up to support "**/*"
