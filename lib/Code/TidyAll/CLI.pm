package Code::TidyAll::CLI;

use strict;
use warnings;

#use Devel::Confess;
use Capture::Tiny qw( capture_merged );
use Code::TidyAll;
use Config;
use List::Util qw( first );
use Module::Runtime qw( require_module );
use Path::Tiny qw( cwd path );
use Specio::Declare;
use Specio::Library::Builtins;
use Specio::Library::Numeric;
use Specio::Library::String;

use Moo;
use MooX::Options (
    usage_string => <<'EOF',
Usage: %c [options] [file] ...
See https://metacpan.org/module/tidyall for full documentation.
EOF
);

our $VERSION = '0.70';

option all => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 'a',
    doc     => 'Process all files in this project',
);

option ignore => (
    is      => 'ro',
    isa     => t( 'ArrayRef', of => t('NonEmptyStr') ),
    default => sub { [] },
    format  => 's@',
    short   => 'i',
    doc     => 'Ignore matching files, specified using zglob syntax - can be passed multiple times'
);

option git => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 'g',
    doc     => 'Process all added or modified files based on git status',
);

option list_only => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 'l',
    doc =>
        q{List each file along with the plugins that would apply to it, but don't actually do anything to the files},
);

option mode => (
    is     => 'ro',
    isa    => t('NonEmptyStr'),
    format => 's',
    short  => 'm',
    doc =>
        q{The mode in which to run (e.g. "editor", "commit") - can be used to control which plugins are run},
);

option pipe => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_pipe',
    format    => 's',
    short     => 'p',
    doc =>
        'Read from STDIN and output to STDOUT/STDERR using the given filename to determine what plugins to run',
);

option recursive => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 'r',
    doc     => 'Descend recursively into directories passed on the command line',
);

option jobs => (
    is    => 'ro',
    isa   => t('PositiveInt'),
    short => 'j',
    doc   => 'If this is greater than one, then files are processed in $jobs parallel jobs',
);

option svn => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 's',
    doc     => 'Process all added or modified files based on svn status',
);

option quiet => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 'q',
    doc     => 'Suppresses all output except for errors',
);

option verbose => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    short   => 'v',
    doc     => 'Adds extra verbose output',
);

option inc => (
    is      => 'ro',
    isa     => t( 'ArrayRef', of => t('NonEmptyStr') ),
    default => sub { [] },
    format  => 's@',
    short   => 'I',
    doc     => 'Adds one or more paths to @INC',
);

option list_perl_deps => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
short => 'list-perl-deps',
    doc => 'Print a list of required Perl modules based on the configuration file, one per line',
);

option backup_ttl => (
    is     => 'ro',
    isa    => t('PositiveInt'),
    format => 'i',
    doc    => 'Amount of time before backup files can be purged, as a duration in seconds',
);

option check_only => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    doc     => 'Check files but do not modify them',
);

option conf_file => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_conf_file',
    format    => 's',
    doc       => 'Relative or absolute path to a configuration file',
);

option conf_name => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_conf_name',
    format    => 's',
    doc       => 'The filename to use when searching for a configuration file',
);

option data_dir => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_data_dir',
    format    => 's',
    doc       => 'The directory in which to store metadata - defaults to $root/.tidyall.d',
);

option no_backups => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    doc     => 'If this is set, then tidyall will not back up files before processing',
);

option no_cache => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    doc =>
        q{If this is set, then tidyall always processes files and doesn't store the last processed time for files in the cache},
);

option no_cleanup => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    doc     => 'If this is set, then tidyall will not clean up temporary files',
);

option output_suffix => (
    is     => 'ro',
    isa    => t('NonEmptyStr'),
    format => 's',
    doc    => 'The suffix to add to tidied files - by default files are tidied in place',
);

option plugins => (
    is      => 'ro',
    isa     => t( 'ArrayRef', of => t('NonEmptyStr') ),
    default => sub { [] },
    format  => 's@',
    doc     => 'Only run the named plugins - can be passed multiple times'
);

option refresh_cache => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    doc     => 'Erase any existing cache info before processing each file',
);

option root_dir => (
    is        => 'ro',
    isa       => t('NonEmptyStr'),
    predicate => '_has_root_dir',
    format    => 's',
    doc =>
        'The root directory for the project - by default this is the directory that contains the configuration file',
);

option tidyall_class => (
    is      => 'ro',
    isa     => t('NonEmptyStr'),
    default => 'Code::TidyAll',
    format  => 's',
    doc     => 'The class to instantiate instead of Code::TidyAll',
);

option version => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
    doc     => 'Show version information and exit',
);

has _ct => (
    is      => 'ro',
    isa     => object_isa_type('Code::TidyAll'),
    lazy    => 1,
    builder => '_build_ct',
);

has _paths => (
    is      => 'ro',
    isa     => t( 'ArrayRef', of => t('NonEmptyStr') ),
    default => sub { [] },
);

has _data_dir => (
    is      => 'ro',
    isa     => object_isa_type('Path::Tiny'),
    lazy    => 1,
    default => sub { path( $_[0]->data_dir ) },
);

has _root_dir => (
    is      => 'ro',
    isa     => object_isa_type('Path::Tiny'),
    lazy    => 1,
    default => sub { path( $_[0]->root_dir ) },
);

has _pipe => (
    is      => 'ro',
    isa     => object_isa_type('Path::Tiny'),
    lazy    => 1,
    default => sub { path( $_[0]->pipe ) },
);

has _tidyall_class => (
    is      => 'ro',
    isa     => t('ClassName'),
    lazy    => 1,
    default => sub {
        require_module( $_[0]->tidyall_class );
        $_[0]->tidyall_class;
    },
);

sub run {
    my $self = shift;

    $self->_maybe_set_inc;

    exit $self->_print_version   if $self->version;
    exit $self->_print_perl_deps if $self->list_perl_deps;
    exit $self->_process_pipe    if $self->_has_pipe;
    exit $self->_process_paths;
}

sub _maybe_set_inc {
    my $self = shift;
    unshift @INC, split( /\s*,\s*/, $self->inc ) if $self->inc;
    return;
}

sub _print_version {
    print "tidyall $VERSION on perl $] built for $Config{archname}\n";
    return 0;
}

sub _print_perl_deps {
    print "Deps\n";
    return 0;
}

sub _process_pipe {
    my $self = shift;

    my $ct = $self->_make_ct(
        no_backups => 1,
        no_cache   => 1,
        quiet      => 1,
        verbose    => 0,
    );

    my $source = do { local $/; <STDIN> };

    # We merge stdout and stderr and print all of the output to stderr. This
    # ensures that stdout is dedicated to the content (which may have been
    # tidied).
    my $result;
    my $output = capture_merged {
        $result = $ct->process_source( $source, $ct->_small_path( $self->_pipe->absolute ) );
    };
    print STDERR $output if defined $output;

    if ( my $error = $result->error ) {

        # The actual error should already have been printed when we printed the output to STDERR above.
        print $source;
        return 1;
    }
    elsif ( $result->state eq 'no_match' ) {
        print $source;
        my $pipe = $self->_pipe;
        print STDERR qq{No plugins apply for '$pipe' in config};
        return 1;
    }
    elsif ( $result->state eq 'checked' ) {
        print $source;
        return 0;
    }

    print $result->new_contents;
    return 0;
}

sub _process_paths {
    my $self = shift;

    my $ct = $self->_make_ct;

    my @paths = $self->_paths_to_process($ct)
        or return 0;

    return ( grep { $_->error } $ct->process_paths(@paths) ) ? 1 : 0;
}

sub _paths_to_process {
    my $self = shift;
    my $ct   = shift;

    # XXX - This is the only spot where we exit outside of run(). Is there a
    # sane way to move this exit handling to run()?
    my @paths;
    if ( $self->all ) {
        @paths = $ct->find_matched_files;
        unless (@paths) {
            print 'You passed --all but we could not find any files to process under '
                . $ct->root_dir . "\n";
            $self->options_usage;
            exit 1;
        }
    }
    elsif ( $self->svn ) {
        require Code::TidyAll::SVN::Util;
        return Code::TidyAll::SVN::Util::svn_uncommitted_files( $ct->root_dir );
    }
    elsif ( $self->git ) {
        require Code::TidyAll::Git::Util;
        return Code::TidyAll::Git::Util::git_modified_files( $ct->root_dir );
    }
    else {
        @paths = map { path($_) } @ARGV;
        unless (@paths) {
            print
                "You must pass -a/--all, -g/--git, -s/--svn, -p/--pipe, or a list of path to process\n";
            $self->options_usage;
            exit 1;
        }
    }

    return @paths;
}

sub _make_ct {
    my $self = shift;

    my %params = ( $self->_tidyall_constructor_params, @_ );
    return $self->_tidyall_class->new_from_conf_file( $self->_find_conf_file, %params );
}

sub _tidyall_constructor_params {
    my $self = shift;

    my @possible = qw(
        backup_ttl
        check_only
        ignore
        jobs
        list_only
        mode
        no_backups
        no_cache
        no_cleanup
        output_suffix
        quiet
        recursive
        refresh_cache
        tidyall_class
        verbose
    );

    my %params;
    for my $p (@possible) {
        my $v = $self->$p();
        next unless defined $v;
        $params{$p} = $v;
    }

    $params{plugins} = $self->selected_plugins
        if defined $self->selected_plugins;

    for my $dir (qw( data_dir root_dir )) {
        my $pred = '_has_' . $dir;
        next unless $self->$pred();
        my $meth = q{_} . $dir;
        $params{$dir} = $self->$meth();
    }

    return %params;
}

sub _find_conf_file {
    my $self = shift;

    return path( $self->conf_file ) if $self->_has_conf_file;

    my @conf_names = $self->_has_conf_name ? $self->conf_name : Code::TidyAll->default_conf_names;
    if ( $self->_has_root_dir ) {
        my $file = first { $_->is_file } map { $self->_root_dir->child($_) } @conf_names;
        return $file if $file;
    }

    my $find_conf_in
        = $self->_has_pipe   ? $self->_pipe->parent
        : @{ $self->_paths } ? $self->_paths->[0]->parent
        :                      cwd();
    return $self->_tidyall_class->find_conf_file( \@conf_names, $find_conf_in );
}

1;
