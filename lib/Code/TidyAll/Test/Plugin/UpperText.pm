package Code::TidyAll::Test::Plugin::UpperText;
use base qw(Code::TidyAll::Plugin);
use strict;
use warnings;

sub defaults {
    return { include => qr/\.txt$/ };
}

sub process_source {
    my ( $self, $source ) = @_;
    if ( $source =~ /^[A-Z]*$/i ) {
        return uc($source);
    }
    else {
        die "non-alpha content found";
    }
}

1;
