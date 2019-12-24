package Code::TidyAll::Plugin;

use strict;
use warnings;

use Code::TidyAll::Util::Zglob qw(zglobs_to_regex);
use File::Which qw(which);
use IPC::Run3 qw(run3);
use Scalar::Util qw(weaken);
use Specio::Declare;
use Specio::Library::Builtins;
use Specio::Library::Numeric;
use Specio::Library::String;
use Text::Diff 1.44 qw(diff);

use Moo;

our $VERSION = '0.76';

has argv => (
    is      => 'ro',
    isa     => t('Str'),
    default => q{}
);

# This really belongs in Code::TidyAll::Role::RunsCommand but moving it there
# breaks plugins not in the core distro that expect to just inherit from this
# module and be able to specify a cmd attribute.
has cmd => (
    is      => 'ro',
    isa     => t('NonEmptyStr'),
    lazy    => 1,
    builder => '_build_cmd',
);

has diff_on_tidy_error => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0
);

has is_tidier => (
    is  => 'lazy',
    isa => t('Bool'),
);

has is_validator => (
    is  => 'lazy',
    isa => t('Bool'),
);

has name => (
    is       => 'ro',
    required => 1
);

has select => (
    is  => 'lazy',
    isa => t( 'ArrayRef', of => t('NonEmptyStr') ),
);

has select_regex => (
    is  => 'lazy',
    isa => t('RegexpRef'),
);

has selects => (
    is  => 'lazy',
    isa => t( 'ArrayRef', of => t('NonEmptyStr') ),
);

has shebang => (
    is  => 'ro',
    isa => t( 'ArrayRef', of => t('NonEmptyStr') ),
);

has tidyall => (
    is => 'ro',

    # This should be "object_isa_type( class => 'Code::TidyAll' )" but then
    # we'd need to load Code::TidyAll, leading to a circular require
    # situation.
    isa      => t('Object'),
    required => 1,
    weak_ref => 1
);

has weight => (
    is  => 'lazy',
    isa => t('PositiveOrZeroInt'),
);

with 'Code::TidyAll::Role::HasIgnore';

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $class->$orig(@_);

    for my $key (qw( ignore select shebang )) {
        if ( defined $args->{$key} && !ref $args->{$key} ) {
            $args->{$key} = [ $args->{$key} ];
        }
    }

    return $args;
};

sub _build_cmd {
    die 'no default cmd specified';
}

sub _build_selects {
    my ($self) = @_;
    return $self->_parse_zglob_list( $self->select );
}

sub _build_select_regex {
    my ($self) = @_;
    return zglobs_to_regex( @{ $self->selects } );
}

sub _build_is_tidier {
    my ($self) = @_;
    return ( $self->can('transform_source') || $self->can('transform_file') ) ? 1 : 0;
}

sub _build_is_validator {
    my ($self) = @_;
    return ( $self->can('validate_source') || $self->can('validate_file') ) ? 1 : 0;
}

# default weight
sub _build_weight {
    my ($self) = @_;
    return 60 if $self->is_validator;
    return 50;
}

sub BUILD {
    my ( $self, $params ) = @_;

    # Strict constructor
    #
    $self->validate_params($params);
}

sub validate_params {
    my ( $self, $params ) = @_;

    delete( $params->{only_modes} );
    delete( $params->{except_modes} );
    if ( my @bad_params = grep { !$self->can($_) } keys(%$params) ) {
        die sprintf(
            q{unknown option%s %s for plugin '%s'},
            @bad_params > 1 ? 's' : q{},
            join( ', ', sort map {qq['$_']} @bad_params ),
            $self->name
        );
    }
}

# No-ops by default; may be overridden in subclass
sub preprocess_source {
    return $_[1];
}

sub postprocess_source {
    return $_[1];
}

sub process_source_or_file {
    my ( $self, $orig_source, $rel_path, $check_only ) = @_;

    my $new_source = $orig_source;
    if ( $self->can('transform_source') ) {
        foreach my $iter ( 1 .. $self->tidyall->iterations ) {
            $new_source = $self->transform_source($new_source);
        }
    }
    if ( $self->can('transform_file') ) {
        my $tempfile = $self->_write_temp_file( $rel_path, $new_source );
        foreach my $iter ( 1 .. $self->tidyall->iterations ) {
            $self->transform_file($tempfile);
        }
        $new_source = $tempfile->slurp;
    }
    if ( $self->can('validate_source') ) {
        $self->validate_source($new_source);
    }
    if ( $self->can('validate_file') ) {
        my $tempfile = $self->_write_temp_file( $rel_path, $new_source );
        $self->validate_file($tempfile);
    }

    my $diff;
    if ( $check_only && $new_source ne $orig_source ) {
        $diff = $self->_maybe_diff( $orig_source, $new_source, $rel_path );
    }

    return ( $new_source, $diff );
}

sub _maybe_diff {
    my $self = shift;

    return unless $self->diff_on_tidy_error;

    my $orig     = shift;
    my $new      = shift;
    my $rel_path = shift;

    my $orig_file = $self->_write_temp_file( $rel_path . '.orig', $orig );
    my $new_file  = $self->_write_temp_file( $rel_path . '.new',  $new );

    return diff( $orig_file->stringify, $new_file->stringify, { Style => 'Unified' } );
}

sub _write_temp_file {
    my ( $self, $rel_path, $source ) = @_;

    my $tempfile = $self->tidyall->_tempdir->child($rel_path);
    $tempfile->parent->mkpath( { mode => 0755 } );
    $tempfile->spew($source);
    return $tempfile;
}

sub matches_path {
    my ( $self, $path ) = @_;

    return
           $path =~ $self->select_regex
        && $path !~ $self->tidyall->ignore_regex
        && $path !~ $self->ignore_regex;
}

1;

# ABSTRACT: Create plugins for tidying or validating code

__END__

=pod

=head1 SYNOPSIS

    package Code::TidyAll::Plugin::SomeTidier;
    use Moo;
    extends 'Code::TidyAll::Plugin';

    sub transform_source {
        my ( $self, $source ) = @_;
        ...
        return $source;
    }


    package Code::TidyAll::Plugin::SomeValidator;
    use Moo;
    extends 'Code::TidyAll::Plugin';

    sub validate_file {
        my ( $self, $file ) = @_;
        die 'not valid' if ...;
    }

=head1 DESCRIPTION

To use a tidier or validator with C<tidyall> it must have a corresponding
plugin class that inherits from this class. This document describes how to
implement a new plugin.

The easiest way to start is to look at existing plugins, such as
L<Code::TidyAll::Plugin::PerlTidy> and L<Code::TidyAll::Plugin::PerlCritic>.

=head1 NAMING

If you are going to publicly release your plugin, call it C<<
Code::TidyAll::Plugin::I<something> >> so that users can find it easily and
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

then L<Code::TidyAll::Plugin::PerlCritic> would be constructed with parameters

    Code::TidyAll::Plugin::PerlCritic->new(
        select => 'lib/**/*.pm',
        ignore => 'lib/UtterHack.pm',
        argv   => '-severity 3',
    );

The following attributes are part of this base class. Your subclass can declare
others, of course.

=head2 argv

A standard attribute for passing command line arguments.

=head2 diff_on_tidy_error

This only applies to plugins which transform source. If this is true, then when
the plugin is run in check mode it will include a diff in the return value from
C<process_source_or_file> when the source is not tidy.

=head2 is_validator

An attribute that indicates if this is a validator or not; By default this
returns true if either C<validate_source> or C<validate_file> methods have been
implemented.

=head2 name

Name of the plugin to be used in error messages etc.

=head2 tidyall

A weak reference back to the L<Code::TidyAll> object.

=head2 weight

A number indicating the relative weight of the plugin, used to calculate the
order the plugins will execute in. The lower the number the sooner the plugin
will be executed.

By default the weight will be C<50> for non validators (anything where
C<is_validator> returns false) and C<60> for validators (anything where
C<is_validator> returns true.)

The order of plugin execution is determined first by the value of the C<weight>
attribute, and then (if multiple plugins have the same weight>) by sorting by
the name of module.

=head1 METHODS

Your plugin may define one or more of these methods. They are all no-ops by
default.

=head2 $plugin->preprocess_source($source)

Receives source code as a string; returns the processed string, or dies with
error. This runs on all plugins I<before> any of the other methods.

=head2 $plugin->transform_source($source)

Receives source code as a string; returns the transformed string, or dies with
error. This is repeated multiple times if --iterations was passed or specified
in the configuration file.

=head2 $plugin->transform_file($file)

Receives filename; transforms the file in place, or dies with error. Note that
the file will be a temporary copy of the user's file with the same basename;
your changes will only propagate back if there was no error reported from any
plugin. This is repeated multiple times if --iterations was passed or specified
in the configuration file.

=head2 $plugin->validate_source($source)

Receives source code as a string; dies with error if invalid. Return value will
be ignored.

=head2 $plugin->validate_file($file)

Receives filename; validates file and dies with error if invalid. Should not
modify file! Return value will be ignored.

=head2 $plugin->postprocess_source($source)

Receives source code as a string; returns the processed string, or dies with
error. This runs on all plugins I<after> any of the other methods.

=cut
