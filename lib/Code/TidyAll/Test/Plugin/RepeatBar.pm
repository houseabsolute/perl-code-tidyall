package Code::TidyAll::Test::Plugin::RepeatBar;
use Code::TidyAll::Util qw(read_file write_file);
use base qw(Code::TidyAll::Plugin);
use strict;
use warnings;

sub defaults {
    return { include => qr/foo[^\/]+$/ };
}

sub process_source {
    my ( $self, $source ) = @_;
    my $times = $self->options->{times} || die "no times specified";
    return $source x $times;
}

1;
