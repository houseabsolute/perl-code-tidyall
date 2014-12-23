package Code::TidyAll::Test::Class;

use File::Which qw( which );
use Test::Class::Most;
use strict;
use warnings;

__PACKAGE__->SKIP_CLASS("abstract base class");

sub require_executable {
    my $self = shift;
    my $exe = shift;

    which($exe)
        or $self->FAIL_ALL("These tests require that $exe be in your \$PATH");

    return;
}

1;
