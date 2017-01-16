package Code::TidyAll;

use strict;
use warnings;

use Code::TidyAll::Cache;
use Code::TidyAll::CacheModel;
use Code::TidyAll::Config::INI::Reader;
use Code::TidyAll::Plugin;
use Code::TidyAll::Result;
use Code::TidyAll::Util qw(can_load);
use Code::TidyAll::Util::Zglob qw(zglobs_to_regex);
use Data::Dumper;
use Date::Format;
use Digest::SHA qw(sha1_hex);
use File::Find qw(find);
use File::Zglob;
use List::SomeUtils qw(uniq);
use Path::Tiny qw(path);
use Scalar::Util qw(blessed);
use Specio 0.30;
use Specio::Declare;
use Specio::Library::Builtins;
use Specio::Library::Numeric;
use Specio::Library::Path::Tiny 0.04;
use Specio::Library::String;
use Time::Duration::Parse qw(parse_duration);
use Try::Tiny;

use Moo 2.000000;

our $VERSION = '0.56';

sub default_conf_names { ( 'tidyall.ini', '.tidyallrc' ) }

# External
has 'backup_ttl' => (
    is      => 'ro',
    isa     => t('NonEmptyStr'),
    default => '1 hour',
);

has 'cache' => (
    is  => 'lazy',
    isa => object_can_type( methods => [qw( get set )] ),
);

has 'cache_model_class' => (
    is      => 'ro',
    isa     => t('ClassName'),
    default => 'Code::TidyAll::CacheModel',
);

has 'check_only' => (
    is  => 'ro',
    isa => t('Bool'),
);

has 'data_dir' => (
    is     => 'lazy',
    isa    => t('Path'),
    coerce => t('Path')->coercion_sub,
);

has 'iterations' => (
    is      => 'ro',
    isa     => t('PositiveInt'),
    default => 1,
);

has 'jobs' => (
    is      => 'ro',
    isa     => t('Int'),
    default => 1,
);

has 'list_only' => (
    is  => 'ro',
    isa => t('Bool'),
);

has 'mode' => (
    is      => 'ro',
    isa     => t('NonEmptyStr'),
    default => 'cli',
);

has 'msg_outputter' => (
    is      => 'ro',
    isa     => t('CodeRef'),
    builder => '_build_msg_outputter',
);

has 'no_backups' => (
    is  => 'ro',
    isa => t('Bool'),
);

has 'no_cache' => (
    is  => 'ro',
    isa => t('Bool'),
);

has 'output_suffix' => (
    is      => 'ro',
    isa     => t('Str'),
    default => q{},
);

has 'plugins' => (
    is       => 'ro',
    isa      => t('HashRef'),
    required => 1,
);

has 'global_ignore' => (
    is       => 'ro',
    isa      => t('ArrayRef'),
    required => 0,
);

has 'global_ignore_regex' => ( is => 'lazy' );
has 'global_ignores'      => ( is => 'lazy' );

has 'quiet' => (
    is  => 'ro',
    isa => t('Bool'),
);
has 'recursive' => (
    is  => 'ro',
    isa => t('Bool'),
);

has 'refresh_cache' => (
    is  => 'ro',
    isa => t('Bool'),
);

has 'root_dir' => (
    is       => 'ro',
    isa      => t('RealDir')->_subify,
    coerce   => t('RealDir')->coercion_sub,
    required => 1
);

has 'verbose' => (
    is      => 'ro',
    isa     => t('Bool'),
    default => 0,
);

# Internal
has 'backup_dir' => (
    is       => 'lazy',
    isa      => t('Path'),
    init_arg => undef,
);

has 'backup_ttl_secs' => (
    is       => 'lazy',
    isa      => t('Int'),
    init_arg => undef,
);

has 'base_sig' => (
    is       => 'lazy',
    isa      => t('NonEmptyStr'),
    init_arg => undef,
);

has 'plugin_objects' => (
    is       => 'lazy',
    isa      => t( 'ArrayRef', of => object_isa_type('Code::TidyAll::Plugin') ),
    init_arg => undef,
);

has 'plugins_for_mode' => (
    is       => 'lazy',
    isa      => t( 'HashRef', of => t('HashRef') ),
    init_arg => undef,
);

with 'Code::TidyAll::Role::Tempdir';

sub _build_backup_dir {
    my $self = shift;
    return $self->data_dir->child('backups');
}

sub _build_backup_ttl_secs {
    my $self = shift;
    return parse_duration( $self->backup_ttl );
}

sub _build_base_sig {
    my $self = shift;
    my $active_plugins = join( "|", map { $_->name } @{ $self->plugin_objects } );
    return $self->_sig( [ $Code::TidyAll::VERSION || 0, $active_plugins ] );
}

sub _build_cache {
    my $self = shift;
    return Code::TidyAll::Cache->new( cache_dir => $self->data_dir->child('cache') );
}

sub _build_data_dir {
    my $self = shift;
    return $self->root_dir->child('/.tidyall.d');
}

sub _build_plugins_for_mode {
    my $self    = shift;
    my $plugins = $self->plugins;
    if ( my $mode = $self->mode ) {
        $plugins = {
            map { ( $_, $plugins->{$_} ) }
            grep { $self->_plugin_conf_matches_mode( $plugins->{$_}, $mode ) } keys(%$plugins)
        };
    }
    return $plugins;
}

sub _build_global_ignores {
    my ($self) = @_;
    return $self->_parse_zglob_list( $self->global_ignore );
}

sub _build_global_ignore_regex {
    my ($self) = @_;
    return zglobs_to_regex( @{ $self->global_ignores } );
}

sub _build_plugin_objects {
    my $self = shift;
    my @plugin_objects = map { $self->_load_plugin( $_, $self->plugins->{$_} ) }
        keys( %{ $self->plugins_for_mode } );

    # Sort tidiers by weight (by default validators have a weight of 60 and non-
    # validators a weight of 50 meaning non-validators normally go first), then
    # alphabetical
    # TODO: These should probably sort in a consistent way independent of locale
    return [ sort { ( $a->weight <=> $b->weight ) || ( $a->name cmp $b->name ) } @plugin_objects ];
}

sub BUILD {
    my ( $self, $params ) = @_;

    # Strict constructor
    #
    if ( my @bad_params = grep { !$self->can($_) } keys(%$params) ) {
        die sprintf(
            "unknown constructor param%s %s for %s",
            @bad_params > 1 ? "s" : "",
            join( ", ", sort map {"'$_'"} @bad_params ),
            ref($self)
        );
    }

    $self->{plugins_for_path} = {};

    unless ( $self->no_backups ) {
        $self->backup_dir->mkpath( { mode => 0775 } );
        $self->_purge_backups_periodically();
    }
}

sub new_from_conf_file {
    my ( $class, $conf_file, %params ) = @_;

    $conf_file = path($conf_file);

    die "no such file '$conf_file'" unless $conf_file->is_file;
    my $conf_params = $class->_read_conf_file($conf_file);
    my $main_params = delete( $conf_params->{'_'} ) || {};
    if ( $main_params->{'ignore'} ) {
        $main_params->{global_ignore} = delete $main_params->{'ignore'} || [];
    }

    %params = (
        plugins  => $conf_params,
        root_dir => path($conf_file)->realpath->parent,
        %$main_params, %params
    );

    # Initialize with alternate class if given
    #
    if ( my $tidyall_class = delete( $params{tidyall_class} ) ) {
        die "cannot load '$tidyall_class'" unless can_load($tidyall_class);
        $class = $tidyall_class;
    }

    if ( $params{verbose} ) {
        my $msg_outputter = $params{msg_outputter} || $class->_build_msg_outputter();
        $msg_outputter->(
            "constructing %s with these params: %s", $class,
            _dump_params( \%params )
        );
    }

    return $class->new(%params);
}

sub _dump_params {
    my $p = shift;

    return Data::Dumper->new( [ _recurse_dump($p) ] )->Indent(0)->Sortkeys(1)->Quotekeys(0)
        ->Terse(1)->Dump;
}

# This is all ridiculous workaround the fact that there is no good way to tell
# Data::Dumper how to serialize a Path::Tiny object.
sub _recurse_dump {
    my ($p) = @_;

    my %dump;
    for my $k ( keys %{$p} ) {
        my $v = $p->{$k};
        if ( blessed $v ) {
            if ( $v->isa('Path::Tiny') ) {
                $dump{$k} = $v . q{};
            }
            else {
                die 'Cannot dump ' . ref($v) . ' object';
            }
        }
        elsif ( ref $v eq 'HASH' ) {
            $dump{$k} = _recurse_dump( $p->{$v} );
        }
        elsif ( ref $v eq 'ARRAY' ) {
            $dump{$k} = [ map { _recurse_dump($_) } @{ $p->{$v} } ];
        }
        else {
            $dump{$k} = $v;
        }
    }

    return \%dump;
}

sub _load_plugin {
    my ( $self, $plugin_name, $plugin_conf ) = @_;

    # Extract first name in case there is a description
    #
    my ($plugin_fname) = ( $plugin_name =~ /^(\S+)/ );

    my $plugin_class = (
        $plugin_fname =~ /^\+/
        ? substr( $plugin_fname, 1 )
        : "Code::TidyAll::Plugin::$plugin_fname"
    );
    try {
        can_load($plugin_class) || die "not found";
    }
    catch {
        die "could not load plugin class '$plugin_class': $_";
    };

    return $plugin_class->new(
        class   => $plugin_class,
        name    => $plugin_name,
        tidyall => $self,
        %$plugin_conf
    );
}

sub _plugin_conf_matches_mode {
    my ( $self, $conf, $mode ) = @_;

    if ( my $only_modes = $conf->{only_modes} ) {
        return 0 if ( " " . $only_modes . " " ) !~ / $mode /;
    }
    if ( my $except_modes = $conf->{except_modes} ) {
        return 0 if ( " " . $except_modes . " " ) =~ / $mode /;
    }
    return 1;
}

sub process_all {
    my $self = shift;

    return $self->process_paths( $self->find_matched_files );
}

sub process_paths {
    my ( $self, @paths ) = @_;

    @paths = map {
        try { $_->realpath }
            || $_->absolute
    } map { path($_) } @paths;

    if ( $self->jobs > 1 && @paths > 1 ) {
        return $self->_process_parallel(@paths);
    }
    else {
        return map { $self->process_path($_) } @paths;
    }
}

sub _process_parallel {
    my ( $self, @paths ) = @_;

    unless ( eval { require Parallel::ForkManager; 1; } ) {
        die 'Running Code::TidyAll with multiple jobs requires Parallel::ForkManager';
    }

    my @results;
    my %path_to_pid;

    my $pm = Parallel::ForkManager->new( $self->jobs );
    $pm->set_waitpid_blocking_sleep(0.01);
    $pm->run_on_finish(
        sub {
            my ( $pid, $code, $result ) = @_[ 0, 1, 5 ];

            if ($code) {
                warn "Error running tidyall on $path_to_pid{$pid}. Got exit status of $code.";
            }
            else {
                push @results, $result;
            }
        }
    );

    for my $path (@paths) {
        if ( my $pid = $pm->start ) {
            $path_to_pid{$path} = $pid;
            next;
        }

        $pm->finish( 0, $self->process_path($path) );
    }

    $pm->wait_all_children;

    return @results;
}

sub process_path {
    my ( $self, $path ) = @_;

    if ( $path->is_dir ) {
        if ( $self->recursive ) {
            return $self->process_paths( $path->children );
        }
        else {
            return ( $self->_error_result( "$path: is a directory (try -r/--recursive)", $path ) );
        }
    }
    elsif ( $path->is_file ) {
        return ( $self->process_file($path) );
    }
    else {
        return ( $self->_error_result( "$path: not a file or directory", $path ) );
    }
}

sub process_file {
    my ( $self, $full_path ) = @_;

    $full_path = path($full_path);
    die "$full_path is not a file" unless $full_path->is_file;

    my $path = $self->_small_path($full_path);

    if ( $self->list_only ) {
        if ( my @plugins = $self->plugins_for_path($path) ) {
            $self->msg( "%s (%s)", $path, join( ", ", map { $_->name } @plugins ) );
        }
        return Code::TidyAll::Result->new( path => $path, state => 'checked' );
    }

    my $cache_model = $self->_cache_model_for( $path, $full_path );
    if ( $self->refresh_cache ) {
        $cache_model->remove;
    }
    elsif ( $cache_model->is_cached ) {
        $self->msg( "[cached] %s", $path ) if $self->verbose;
        return Code::TidyAll::Result->new( path => $path, state => 'cached' );
    }

    my $contents = $cache_model->file_contents || $full_path->slurp;
    my $result = $self->process_source( $contents, $path );

    if ( $result->state eq 'tidied' ) {

        # backup original contents
        $self->_backup_file( $path, $contents );

        # write new contents out to disk
        $contents = $result->new_contents;

        # We don't use ->spew because that creates a new file and renames it,
        # losing the existing mode setting in the process.
        path( $full_path . $self->output_suffix )->append( { truncate => 1 }, $contents );

        # change the in memory contents of the cache (but don't update yet)
        $cache_model->file_contents($contents) unless $self->output_suffix;
    }

    $cache_model->update if $result->ok;
    return $result;
}

sub _cache_model_for {
    my ( $self, $path, $full_path ) = @_;
    return $self->cache_model_class->new(
        path         => $path,
        full_path    => $full_path,
        cache_engine => $self->no_cache ? undef : $self->cache,
        base_sig     => $self->base_sig,
    );
}

sub process_source {
    my ( $self, $contents, $path ) = @_;

    die "contents and path required" unless defined($contents) && defined($path);
    my @plugins = $self->plugins_for_path($path);
    if ( !@plugins ) {
        $self->msg(
            "[no plugins apply%s] %s",
            $self->mode ? " for mode '" . $self->mode . "'" : "", $path
        ) if $self->verbose;
        return Code::TidyAll::Result->new( path => $path, state => 'no_match' );
    }

    if ( $self->verbose ) {
        my @names = map { $_->name } @plugins;
        $self->msg("[applying the following plugins: @names]");
    }

    my $new_contents = my $orig_contents = $contents;
    my $plugin;
    my $error;
    my @diffs;
    try {
        foreach my $method (qw(preprocess_source process_source_or_file postprocess_source)) {
            foreach $plugin (@plugins) {
                my $diff;
                ( $new_contents, $diff )
                    = $plugin->$method( $new_contents, $path, $self->check_only );
                if ($diff) {
                    push @diffs, [ $plugin->name, $diff ];
                }
            }
        }
    }
    catch {
        chomp;
        $error = $_;
        $error = sprintf( "*** '%s': %s", $plugin->name, $_ ) if $plugin;
    };

    my $was_tidied = !$error && ( $new_contents ne $orig_contents );
    if ( $was_tidied && $self->check_only ) {
        $error = "*** needs tidying";
        foreach my $diff (@diffs) {
            $error .= "\n\n";
            $error .= "$diff->[0] made the following change:\n$diff->[1]";
        }
        $error .= "\n\n" if @diffs;
        undef $was_tidied;
    }

    if ( !$self->quiet || $error ) {
        my $status = $was_tidied ? "[tidied]  " : "[checked] ";
        my $plugin_names
            = $self->verbose ? sprintf( " (%s)", join( ", ", map { $_->name } @plugins ) ) : "";
        $self->msg( "%s%s%s", $status, $path, $plugin_names );
    }

    if ($error) {
        return $self->_error_result( $error, $path, $orig_contents, $new_contents );
    }
    elsif ($was_tidied) {
        return Code::TidyAll::Result->new(
            path          => $path,
            state         => 'tidied',
            orig_contents => $orig_contents,
            new_contents  => $new_contents
        );
    }
    else {
        return Code::TidyAll::Result->new( path => $path, state => 'checked' );
    }
}

sub _read_conf_file {
    my ( $class, $conf_file ) = @_;
    my $conf_string = $conf_file->slurp_utf8;
    my $root_dir    = $conf_file->parent;
    $conf_string =~ s/\$ROOT/$root_dir/g;
    my $conf_hash = Code::TidyAll::Config::INI::Reader->read_string($conf_string);
    die "'$conf_file' did not evaluate to a hash"
        unless ( ref($conf_hash) eq 'HASH' );
    return $conf_hash;
}

sub _backup_file {
    my ( $self, $path, $contents ) = @_;
    unless ( $self->no_backups ) {
        my $backup_file = $self->backup_dir->child( $self->_backup_filename($path) );
        $backup_file->parent->mkpath( { mode => 0775 } );
        $backup_file->spew($contents);
    }
}

sub _backup_filename {
    my ( $self, $path ) = @_;

    return join( q{}, $path, '-', time2str( "%Y%m%d-%H%M%S", time ), '.bak' );
}

sub _purge_backups_periodically {
    my ($self) = @_;
    my $cache = $self->cache;
    my $last_purge_backups = $cache->get("last_purge_backups") || 0;
    if ( time > $last_purge_backups + $self->backup_ttl_secs ) {
        $self->_purge_backups();
        $cache->set( "last_purge_backups", time() );
    }
}

sub _purge_backups {
    my ($self) = @_;
    $self->msg("purging old backups") if $self->verbose;
    find(
        {
            follow => 0,
            wanted => sub {
                unlink $_ if -f && /\.bak$/ && time > ( stat($_) )[9] + $self->backup_ttl_secs;
            },
            no_chdir => 1
        },
        $self->backup_dir
    );
}

sub find_conf_file {
    my ( $class, $conf_names, $start_dir ) = @_;

    $start_dir = path($start_dir);
    my $path1     = $start_dir->absolute;
    my $path2     = $start_dir->realpath;
    my $conf_file = $class->_find_conf_file_upward( $conf_names, $path1 )
        || $class->_find_conf_file_upward( $conf_names, $path2 );
    unless ( defined $conf_file ) {
        die sprintf(
            "could not find %s upwards from %s",
            join( " or ", @$conf_names ),
            ( $path1 eq $path2 ) ? "'$path1'" : "'$path1' or '$path2'"
        );
    }
    return $conf_file;
}

sub _find_conf_file_upward {
    my ( $class, $conf_names, $search_dir ) = @_;

    my $cnt = 0;
    while (1) {
        foreach my $conf_name (@$conf_names) {
            my $try_path = $search_dir->child($conf_name);
            return $try_path if $try_path->is_file;
        }
        if ( $search_dir eq '/' ) {
            return undef;
        }
        else {
            $search_dir = $search_dir->parent;
        }
        die "inf loop!" if ++$cnt > 100;
    }
}

sub find_matched_files {
    my ($self) = @_;

    my @matched_files;
    my $plugins_for_path = $self->{plugins_for_path};
    my $root_length      = length( $self->root_dir );
    foreach my $plugin ( @{ $self->plugin_objects } ) {
        my @selected = grep { -f && !-l } $self->_zglob( $plugin->selects );
        my @ignores  = ( @{ $self->global_ignores || [] }, @{ $plugin->ignores || [] } );
        if (@ignores) {
            my %is_ignored = map { ( $_, 1 ) } $self->_zglob( \@ignores );
            @selected = grep { !$is_ignored{$_} } @selected;
        }
        if ( my $shebang = $plugin->shebang ) {
            my $re = join '|', map {quotemeta} @{$shebang};
            $re       = qr/^#!.*\b(?:$re)\b/;
            @selected = grep {
                my $fh;
                open $fh, '<', $_ and <$fh> =~ /$re/;
            } @selected;
        }
        push( @matched_files, @selected );
        foreach my $file (@selected) {
            my $path = substr( $file, $root_length + 1 );
            $plugins_for_path->{$path} ||= [];
            push( @{ $plugins_for_path->{$path} }, $plugin );
        }
    }

    return map { path($_) } sort( uniq(@matched_files) );
}

sub plugins_for_path {
    my ( $self, $path ) = @_;

    $self->{plugins_for_path}->{$path}
        ||= [ grep { $_->matches_path($path) } @{ $self->plugin_objects } ];
    return @{ $self->{plugins_for_path}->{$path} };
}

sub _parse_zglob_list {
    my ( $self, $zglobs ) = @_;
    if ( my ($bad_zglob) = ( grep {m{^/}} @{$zglobs} ) ) {
        die "zglob '$bad_zglob' should not begin with slash";
    }
    return $zglobs;
}

sub _zglob {
    my ( $self, $globs ) = @_;

    local $File::Zglob::NOCASE = 0;
    my @files;
    foreach my $glob (@$globs) {
        try {
            push( @files, File::Zglob::zglob( join( "/", $self->root_dir, $glob ) ) );
        }
        catch {
            die "error parsing '$glob': $_";
        }
    }
    return uniq(@files);
}

sub _small_path {
    my ( $self, $path ) = @_;
    die sprintf( "'%s' is not underneath root dir '%s'!", $path, $self->root_dir )
        unless index( $path, $self->root_dir ) == 0;
    return path( substr( $path . q{}, length( $self->root_dir ) + 1 ) );
}

sub _sig {
    my ( $self, $data ) = @_;
    return sha1_hex( join( ",", @$data ) );
}

sub msg {
    my ( $self, $format, @params ) = @_;
    $self->msg_outputter()->( $format, @params );
}

sub _build_msg_outputter {
    return sub {
        my $format = shift;
        printf "$format\n", @_;
    };
}

sub _error_result {
    my ( $self, $msg, $path, $orig_contents, $new_contents ) = @_;
    $self->msg( "%s", $msg );
    return Code::TidyAll::Result->new(
        path          => $path,
        state         => 'error',
        error         => $msg,
        orig_contents => $orig_contents,
        new_contents  => $new_contents,
    );
}

1;

# ABSTRACT: Engine for tidyall, your all-in-one code tidier and validator

__END__

=pod

=encoding UTF-8

=head1 SYNOPSIS

    use Code::TidyAll;

    my $ct = Code::TidyAll->new_from_conf_file(
        '/path/to/conf/file',
        ...
    );

    # or

    my $ct = Code::TidyAll->new(
        root_dir => '/path/to/root',
        plugins  => {
            perltidy => {
                select => 'lib/**/*.(pl|pm)',
                argv => '-noll -it=2',
            },
            ...
        }
    );

    # then...

    $ct->process_paths($file1, $file2);

=head1 DESCRIPTION

This is the engine used by L<tidyall> - read that first to get an overview.

You can call this API from your own program instead of executing C<tidyall>.

=head1 CONSTRUCTION

=head2 Constructor methods

=over

=item new (%params)

The regular constructor. Must pass at least I<plugins> and I<root_dir>.

=item new_with_conf_file ($conf_file, %params)

Takes a conf file path, followed optionally by a set of key/value parameters.
Reads parameters out of the conf file and combines them with the passed
parameters (the latter take precedence), and calls the regular constructor.

If the conf file or params defines I<tidyall_class>, then that class is
constructed instead of C<Code::TidyAll>.

=back

=head2 Constructor parameters

=over

=item plugins

Specify a hash of plugins, each of which is itself a hash of options. This is
equivalent to what would be parsed out of the sections in the configuration
file.

=item cache_model_class

The cache model class. Defaults to C<Code::TidyAll::CacheModel>

=item cache

The cache instance (e.g. an instance of C<Code::TidyAll::Cache> or a C<CHI>
instance.) An instance of C<Code::TidyAll::Cache> is automatically instantiated
by default.

=item backup_ttl

=item check_only

If this is true, then we simply check that files pass validation steps and that
tidying them does not change the file. Any changes from tidying are not
actually written back to the file.

=item no_cleanup

A boolean indicating if we should skip cleaning temporary files or not.
Defaults to false.

=item data_dir

=item iterations

=item mode

=item no_backups

=item no_cache

=item output_suffix

=item quiet

=item root_dir

=item global_ignore

=item verbose

These options are the same as the equivalent C<tidyall> command-line options,
replacing dashes with underscore (e.g. the C<backup-ttl> option becomes
C<backup_ttl> here).

=item msg_outputter

This is a subroutine reference that is called whenever a message needs to be
printed in some way. The sub receives a C<sprintf()> format string followed by
one or more parameters. The default sub used simply calls C<printf "$format\n",
@_> but L<Test::Code::TidyAll> overrides this to use the C<<
Test::Builder->diag >> method.

=back

=head1 METHODS

=over

=item process_paths (path, ...)

Call L</process_file> on each file; descend recursively into each directory if
the C<recursive> flag is on. Return a list of L<Code::TidyAll::Result> objects,
one for each file.

=item process_file (file)

Process the I<file>, meaning

=over

=item *

Check the cache and return immediately if file has not changed

=item *

Apply appropriate matching plugins

=item *

Print success or failure result to STDOUT, depending on quiet/verbose settings

=item *

Write the cache if enabled

=item *

Return a L<Code::TidyAll::Result> object

=back

=item process_source (I<source>, I<path>)

Like L</process_file>, but process the I<source> string instead of a file, and
do not read from or write to the cache. You must still pass the relative
I<path> from the root as the second argument, so that we know which plugins to
apply. Return a L<Code::TidyAll::Result> object.

=item plugins_for_path (I<path>)

Given a relative I<path> from the root, return a list of
L<Code::TidyAll::Plugin> objects that apply to it, or an empty list if no
plugins apply.

=item find_conf_file (I<conf_names>, I<start_dir>)

Class method. Start in the I<start_dir> and work upwards, looking for one of
the I<conf_names>. Return the pathname if found or throw an error if not found.

=item find_matched_files

Returns a list of sorted files that match at least one plugin in configuration.

=back

=cut
