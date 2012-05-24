package Code::TidyAll::Plugin::perlcritic;
use Code::TidyAll::Util qw(write_file tempdir_simple);
use Perl::Critic::Command qw();
use Moose;
use Capture::Tiny qw(capture_merged);
extends 'Code::TidyAll::Plugin';

sub defaults {
    return { include => qr/\.(pl|pm|t)$/ };
}

sub process_file {
    my ( $self, $file ) = @_;

    # Determine arguments
    #
    my @argv = split( /\s/, $self->options->{argv} || '' );
    my $default_profile = $self->root_dir . "/.perlcriticrc";
    my $profile = $self->{options}->{profile} || ( -f $default_profile && $default_profile );
    push( @argv, '--profile', $profile ) if $profile;
    push( @argv, $file );

    # Run perlcritic
    #
    local @ARGV = @argv;
    my $output = capture_merged { Perl::Critic::Command::run() };
    die $output if $output !~ /^.* source OK\n/;

    # Validation only
    #
    return undef;
}

1;
