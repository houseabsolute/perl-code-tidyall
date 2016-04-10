package Code::TidyAll::Config::INI::Reader;

use strict;
use warnings;
use base qw(Config::INI::Reader);

our $VERSION = '0.44';

sub set_value {
    my ( $self, $name, $value ) = @_;

    if ( $name eq 'select' || $name eq 'ignore' ) {
        push @{ $self->{data}{ $self->current_section }{$name} }, $value;
        return;
    }

    die "cannot list multiple config values for '$name'"
        if exists $self->{data}{ $self->current_section }{$name};

    $self->{data}{ $self->current_section }{$name} = $value;
}

1;
