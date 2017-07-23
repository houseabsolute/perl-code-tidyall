package Code::TidyAll::Config::INI::Reader;

use strict;
use warnings;

use base qw(Config::INI::Reader);

our $VERSION = '0.64';

my %multi_value = map { $_ => 1 } qw( ignore inc select shebang );

sub set_value {
    my ( $self, $name, $value ) = @_;

    if ( $multi_value{$name} ) {
        $value =~ s/^\s+|\s+$//g;
        push @{ $self->{data}{ $self->current_section }{$name} }, split /\s+/, $value;
        return;
    }

    die qq{cannot list multiple config values for '$name'}
        if exists $self->{data}{ $self->current_section }{$name};

    $self->{data}{ $self->current_section }{$name} = $value;
}

1;
