package TestHelper::Plugin::UpperText;

use Moo;
extends 'Code::TidyAll::Plugin';

sub transform_source {
    my ( $self, $source ) = @_;
    if ( $source =~ /^[A-Z\r\n]*$/mi ) {
        return uc($source);
    }
    else {
        die "non-alpha content found";
    }
}

1;
