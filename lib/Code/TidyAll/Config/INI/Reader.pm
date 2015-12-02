package Code::TidyAll::Config::INI::Reader;

use strict;
use warnings;
use base qw(Config::INI::Reader);

our $VERSION = '0.37';

sub set_value {
    my ( $self, $name, $value ) = @_;

    if ( exists( $self->{data}{ $self->current_section }{$name} ) ) {
        die "cannot list multiple config values for '$name'"
            unless $name =~ /select|ignore/;
        $self->{data}{ $self->current_section }{$name} .= " " . $value;
    }
    else {
        $self->{data}{ $self->current_section }{$name} = $value;
    }
}

1;
