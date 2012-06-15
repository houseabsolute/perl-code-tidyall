package Code::TidyAll::Plugin::PerlCritic;
use Code::TidyAll::Util qw(write_file);
use Perl::Critic::Command qw();
use Capture::Tiny qw(capture_merged);
use strict;
use warnings;
use base qw(Code::TidyAll::Plugin);

sub process_file {
    my ( $self, $file ) = @_;
    my $options = $self->options;

    # Determine arguments
    #
    my @argv = split( /\s/, $options->{argv} || '' );
    push( @argv, $file );

    # Run perlcritic
    #
    local @ARGV = @argv;
    my $output = capture_merged { Perl::Critic::Command::run() };
    die $output if $output !~ /^.* source OK\n/;
}

1;
