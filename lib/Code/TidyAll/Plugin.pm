package Code::TidyAll::Plugin;
use Object::Tiny qw(conf ignore name options root_dir select);
use Code::TidyAll::Util qw(basename read_file tempdir_simple write_file);
use Code::TidyAll::Util::Zglob qw(zglob_to_regex);
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    die "conf required" unless $self->{conf};
    die "name required" unless $self->{name};

    my $name = $self->{name};
    $self->{select} = $self->{conf}->{select}
      or die "select required for '$name'";
    die "select for '$name' should not begin with /" if substr( $self->{select}, 0, 1 ) eq '/';
    $self->{ignore} = $self->{conf}->{ignore};
    die "ignore for '$name' should not begin with /"
      if defined( $self->{ignore} ) && substr( $self->{ignore}, 0, 1 ) eq '/';
    $self->{options} = $self->_build_options();

    return $self;
}

sub process_source_or_file {
    my ( $self, $source, $file ) = @_;

    if ( $self->can('process_source') ) {
        return $self->process_source($source);
    }
    elsif ( $self->can('process_file') ) {
        my $tempfile = join( "/", tempdir_simple(), basename($file) );
        write_file( $tempfile, $source );
        $self->process_file($tempfile);
        return read_file($tempfile);
    }
    elsif ( $self->can('validate_source') ) {
        $self->validate_source($source);
        return $source;
    }
    elsif ( $self->can('validate_file') ) {
        $self->validate_file($file);
        return $source;
    }
    else {
        die sprintf(
            "plugin '%s' must implement one of process_file, process_source, validate_file, or validate_source",
            $self->name );
    }
}

sub _build_options {
    my $self    = shift;
    my %options = %{ $self->{conf} };
    delete( @options{qw(select ignore)} );
    return \%options;
}

sub matches_path {
    my ( $self, $path ) = @_;
    $self->{select_regex} ||= zglob_to_regex( $self->select );
    $self->{ignore_regex} ||= ( $self->ignore ? zglob_to_regex( $self->ignore ) : qr/(?!)/ );
    return $path =~ $self->{select_regex} && $path !~ $self->{ignore_regex};
}

1;
__END__

=pod

=head1 NAME

Code::TidyAll::Plugin - Create plugins for tidying or validating code

=head1 SYNOPSIS

To use a tidier or validator with C<tidyall> it must have a corresponding
plugin class that inherits from this class. This document describes how to
implement a new plugin.

The easiest way to start is to look at existing plugins, such as
L<Code::TidyAll::Plugin::PerlTidy|Code::TidyAll::Plugin::PerlTidy> and
L<Code::TidyAll::Plugin::PerlCritic|Code::TidyAll::Plugin::PerlCritic>.

=head1 NAMING

If you are going to publicly release your plugin, call it
'Code::TidyAll::Plugin::I<something>' so that users can find it easily and
refer to it by its short name in configuration.

If it's an internal plugin, you can call it whatever you like and refer to it
with a plus sign prefix in the config file, e.g.

    [+My::Tidier::Class]
    select = **/*.{pl,pm,t}

=head1 METHODS

Your class should define I<one and only one> of these methods. The first two
methods are for tidiers (which actually modify code); the second two are for
validators (which simply check code for errors). C<tidyall> can be a bit more
efficient with the latter, e.g. avoid a file copy.

=over

=item process_source ($source)

Receives source code as a string; returns the processed string, or dies with
error.

=item process_file ($file)

Receives filename; processes the file in place, or dies with error. Note that
the file will be a temporary copy of the user's file with the same basename;
your changes will only propagate back if there was no error reported from any
plugin.

=item validate_source ($source)

Receives source code as a string; dies with error if invalid. Return value will
be ignored.

=item validate_file ($file)

Receives filename; validates file and dies with error if invalid. Should not
modify file!

=back
