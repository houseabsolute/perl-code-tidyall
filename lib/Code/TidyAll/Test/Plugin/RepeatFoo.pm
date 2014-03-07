package Code::TidyAll::Test::Plugin::RepeatFoo;

use Code::TidyAll::Util qw(read_file write_file);
use Moo;
extends 'Code::TidyAll::Plugin';

has 'times' => ( is => 'ro' );

sub transform_source {
    my ( $self, $source ) = @_;
    my $times = $self->times || die "no times specified";
    return $source x $times;
}

1;
