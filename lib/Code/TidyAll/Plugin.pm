package Code::TidyAll::Plugin;
use Code::TidyAll::Util qw(basename read_file write_file);
use Code::TidyAll::Util::Zglob qw(zglob_to_regex);
use Scalar::Util qw(weaken);
use Moo;

# External
has 'argv'    => ( is => 'ro', default => sub { '' } );
has 'cmd'     => ( is => 'lazy' );
has 'ignore'  => ( is => 'ro' );
has 'name'    => ( is => 'ro', required => 1 );
has 'select'  => ( is => 'ro' );
has 'tidyall' => ( is => 'ro', required => 1, weak_ref => 1 );

# Internal
has 'ignore_regex' => ( is => 'lazy' );
has 'select_regex' => ( is => 'lazy' );

sub BUILD {
    my ( $self, $params ) = @_;

    my $select = $self->{select};
    die sprintf( "select is required for '%s'", $self->name ) unless defined($select);
    die sprintf( "select for '%s' should not begin with /", $self->name )
      if ( substr( $select, 0, 1 ) eq '/' );

    my $ignore = $self->{ignore};
    die sprintf( "ignore for '%s' should not begin with /", $self->name )
      if ( defined($ignore) && substr( $ignore, 0, 1 ) eq '/' );
}

sub _build_cmd {
    die "no default cmd specified";
}

sub _build_select_regex {
    my ($self) = @_;
    return zglob_to_regex( $self->select );
}

sub _build_ignore_regex {
    my ($self) = @_;
    return $self->ignore ? zglob_to_regex( $self->ignore ) : qr/(?!)/;
}

# No-ops by default; may be overridden in subclass
sub preprocess_source {
    return $_[1];
}

sub postprocess_source {
    return $_[1];
}

sub process_source_or_file {
    my ( $self, $source, $basename ) = @_;

    if ( $self->can('transform_source') ) {
        $source = $self->transform_source($source);
    }
    if ( $self->can('transform_file') ) {
        my $tempfile = $self->_write_temp_file( $basename, $source );
        $self->transform_file($tempfile);
        $source = read_file($tempfile);
    }
    if ( $self->can('validate_source') ) {
        $self->validate_source($source);
    }
    if ( $self->can('validate_file') ) {
        my $tempfile = $self->_write_temp_file( $basename, $source );
        $self->validate_file($tempfile);
    }

    return $source;
}

sub _write_temp_file {
    my ( $self, $basename, $source ) = @_;

    my $tempfile = join( "/", $self->tidyall->_tempdir(), $basename );
    write_file( $tempfile, $source );
    return $tempfile;
}

sub matches_path {
    my ( $self, $path ) = @_;
    return $path =~ $self->select_regex && $path !~ $self->ignore_regex;
}

1;
__END__

=pod

=head1 NAME

Code::TidyAll::Plugin - Create plugins for tidying or validating code

=head1 SYNOPSIS

    package Code::TidyAll::Plugin::SomeTidier;
    use Moo;
    extends 'Code::TidyAll::Plugin';
    
    sub transform_source {
        my ( $self, source ) = @_;
        ...
        return $source;
    }


    package Code::TidyAll::Plugin::SomeValidator;
    use Moo;
    extends 'Code::TidyAll::Plugin';
    
    sub validate_file {
        my ( $self, $file ) = @_;
        die "not valid" if ...;
    }

=head1 DESCRIPTION

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

=head1 CONSTRUCTOR AND ATTRIBUTES

Your plugin constructor will be called with the configuration key/value pairs
as parameters. e.g. given

    [PerlCritic]
    select = lib/**/*.pm
    ignore = lib/UtterHack.pm
    argv = -severity 3

then L<Code::TidyAll::Plugin::PerlCritic|Code::TidyAll::Plugin::PerlCritic>
would be construted with parameters

    select => 'lib/**/*.pm', 
    ignore = 'lib/UtterHack.pm',
    argv = '-severity 3'

The following attributes are part of this base class. Your subclass can declare
others, of course.

=over

=item argv

A standard attribute for passing command line arguments.

=item cmd

A standard attribute for specifying the name of the command to run, e.g.
"/usr/local/bin/perlcritic".

=item name

Name of the plugin to be used in error messages etc.

=item tidyall

A weak reference back to the L<Code::TidyAll|Code::TidyAll> object.

=item select, ignore

Select and ignore patterns - you can ignore these.

=back

=head1 METHODS

Your plugin may define one or more of these methods. They are all no-ops by
default.

=over

=item preprocess_source ($source)

Receives source code as a string; returns the processed string, or dies with
error. This runs on all plugins I<before> any of the other methods.

=item transform_source ($source)

Receives source code as a string; returns the transformed string, or dies with
error.

=item transform_file ($file)

Receives filename; transforms the file in place, or dies with error. Note that
the file will be a temporary copy of the user's file with the same basename;
your changes will only propagate back if there was no error reported from any
plugin.

=item validate_source ($source)

Receives source code as a string; dies with error if invalid. Return value will
be ignored.

=item validate_file ($file)

Receives filename; validates file and dies with error if invalid. Should not
modify file! Return value will be ignored.

=item postprocess_source ($source)

Receives source code as a string; returns the processed string, or dies with
error. This runs on all plugins I<after> any of the other methods.

=back
