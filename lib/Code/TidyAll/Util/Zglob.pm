# This is a copy of Text::Glob, modified to support "**/"
#
package Code::TidyAll::Util::Zglob;
use strict;
use Exporter;
use vars qw/$VERSION @ISA @EXPORT_OK
  $strict_leading_dot $strict_wildcard_slash/;
$VERSION   = '0.08';
@ISA       = 'Exporter';
@EXPORT_OK = qw( zglob_to_regex );

$strict_leading_dot    = 1;
$strict_wildcard_slash = 1;

use constant debug => 0;

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
            || $_ eq '%' )
        {
            $regex .= "\\$_";
        }
        elsif ( $_ eq "\cZ" ) {    # handle **/ - if escaping, only escape first *
            $regex .=
              $escaping
              ? ( "\\*" . ( $strict_wildcard_slash ? "[^/]*" : ".*" ) . "/" )
              : ".*";
        }
        elsif ( $_ eq '*' ) {
            $regex .=
                $escaping              ? "\\*"
              : $strict_wildcard_slash ? "[^/]*"
              :                          ".*";
        }
        elsif ( $_ eq '?' ) {
            $regex .=
                $escaping              ? "\\?"
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
__END__
