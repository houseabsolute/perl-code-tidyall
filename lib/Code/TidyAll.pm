package Code::TidyAll;
use Cwd qw(realpath);
use Config::INI::Reader;
use Code::TidyAll::Cache;
use Code::TidyAll::Util qw(can_load read_file);
use Digest::SHA1 qw(sha1_hex);
use File::Find qw(find);
use JSON::XS qw(encode_json);
use strict;
use warnings;

# Incoming parameters
use Object::Tiny qw(
  backup_dir
  cache
  cache_dir
  conf_file
  data_dir
  plugins
  recursive
);

# Internal
use Object::Tiny qw(
  base_sig
  plugin_objects
);

sub new {
    my $class  = shift;
    my %params = @_;

    # Read params from conf file, if provided; handle .../ upward search syntax
    #
    if ( my $conf_file = delete( $params{conf_file} ) ) {
        if ( my ( $start_dir, $search_file ) = ( $conf_file =~ m{^(.*)\.\.\./(.*)$} ) ) {
            $start_dir = '.' if !$start_dir;
            $start_dir = realpath($start_dir);
            if ( my $found_file = $class->_find_file_upwards( $start_dir, $search_file ) ) {
                $conf_file = $found_file;
            }
            else {
                die "cound not find '$search_file' upwards from '$start_dir'";
            }
        }

        my $conf_params = Config::INI::Reader->read_file($conf_file);
        if ( ref($conf_params) ne 'HASH' ) {
            die "'$conf_file' did not evaluate to a hash";
        }
        my $main_params = delete( $conf_params_ > {_} ) || {};
        %params = ( plugins => $conf_params, %$main_params, %params );
    }

    my $self = $class->SUPER::new(%params);
    die "plugins required" unless $self->{plugins};

    if ( defined( $self->data_dir ) ) {
        $self->{backup_dir} ||= $self->data_dir . "/backup";
        $self->{cache_dir}  ||= $self->data_dir . "/cache";
    }
    if ( defined( $self->cache_dir ) ) {
        $self->{cache} ||= Code::TidyAll::Cache->new( cache_dir => $self->cache_dir );
    }
    $self->{base_sig} = $self->_sig( [ $Code::TidyAll::VERSION, $self->plugins ] );

    my $plugins = $self->plugins;
    $self->{plugin_objects} =
      [ map { $self->load_plugin( $_, $plugins->{$_} ) } keys( %{ $self->plugins } ) ];

    return $self;
}

sub load_plugin {
    my ( $self, $plugin_name, $plugin_conf ) = @_;
    my $class_name = (
        $plugin_name =~ /^\+/
        ? substr( $plugin_name, 1 )
        : "Code::TidyAll::Plugin::$plugin_name"
    );
    if ( can_load($class_name) ) {
        return $class_name->new(
            conf => $plugin_conf,
            name => $plugin_name
        );
    }
    else {
        die "could not load plugin class '$class_name'";
    }
}

sub process_path {
    my ( $self, $path ) = @_;

        ( -f $path ) ? $self->process_file($path)
      : ( -d $path ) ? $self->process_dir($path)
      :                printf( "%s: not a file or directory\n", $path );
}

sub process_dir {
    my ( $self, $dir ) = @_;
    printf( "%s: skipping dir, not in recursive mode\n", $dir ) unless $self->recursive;
    my @files;
    find( { wanted => sub { push @files, $_ if -f }, no_chdir => 1 }, $dir );
    foreach my $file (@files) {
        $self->process_file($file);
    }
}

sub process_file {
    my ( $self, $file ) = @_;
    my $cache = $self->cache;
    if ( !$cache || ( ( $cache->get($file) || '' ) ne $self->_file_sig($file) ) ) {
        my $matched = 0;
        foreach my $plugin ( @{ $self->plugin_objects } ) {
            if ( $plugin->matcher->($file) ) {
                print "$file\n" if !$matched++;
                eval { $plugin->process_file($file) };
                if ( my $error = $@ ) {
                    printf( "*** '%s': %s\n", $plugin->name, $error );
                    return;
                }
            }
        }
        $cache->set( $file, $self->_file_sig($file) ) if $cache;
    }
}

sub files_from_svn_status {
    my ( $class, $dir ) = @_;

    my $buffer = `cd $dir; svn status`;
    my @paths = ( $buffer =~ /^[AM]\s+(.*)/gm );
    return $class->_files_from_vcs_status( $dir, @paths );
}

sub files_from_git_status {
    my ( $class, $dir ) = @_;

    my $buffer = `cd $dir; git status`;
    my @paths = ( $buffer =~ /(?:new file|modified):\s+(.*)/g );
    return $class->_files_from_vcs_status( $dir, @paths );
}

sub _files_from_vcs_status {
    my (@files) = @_;

    return grep { -f } uniq( map { "$dir/$_" } @files );
}

sub _find_file_upwards {
    my ( $class, $search_dir, $search_file ) = @_;

    $search_dir  =~ s{/+$}{};
    $search_file =~ s{^/+}{};

    while (1) {
        my $try_path = "$search_dir/$search_file";
        if ( -f $try_path ) {
            return $try_path;
        }
        elsif ( $search_dir eq '/' ) {
            return undef;
        }
        else {
            $search_dir = dirname($search_dir);
        }
    }
}

sub _file_sig {
    my ( $self, $file ) = @_;
    my $last_mod = ( stat($file) )[9];
    my $contents = read_file($file);
    return $self->_sig( [ $self->base_sig, $last_mod, $contents ] );
}

sub _sig {
    my ( $self, $data ) = @_;
    return sha1_hex( encode_json($data) );
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll - Engine for tidyall, your all-in-one code tidier and validator

=head1 SYNOPSIS

    use Code::TidyAll;

    my $ct = Code::TidyAll->new(
        data_dir => '/tmp/.tidyall',
        recursive => 1,
        plugins  => {
            perltidy => {
                include => qr/\.(pl|pm|t)$/,
                options => { argv => '-noll -it=2' },
            },
            perlcritic => {
                include => qr/\.(pl|pm|t)$/,
                options => { '-include' => ['layout'], '-severity' => 3, }
            },
            podtidy => {
                include => qr/\.(pl|pm|t)$/,
                options => { columns => 80 }
            },
            htmltidy => {
                include => qr/\.html$/,
                options => {
                    output_xhtml => 1,
                    tidy_mark    => 0,
                }
            },
            '+My::Javascript::Tidier' => {
                include => qr/\.js$/,
                ...
            }, 
        }
    );
    $ct->process_path($path1, $path2);

=head1 DESCRIPTION

=head1 CONSTRUCTOR OPTIONS

=over

=item plugins

Required. A hash of one or more plugin specifications.

Each key is the name of a plugin; it is automatically prefixed with
C<TidyAll::Plugin::> unless it is a full classname preceded by a '+'.

Each value is a configuration hash for the plugin. The configuration hash may
contain:

=over

=item include

A regex or code reference which is applied to each full pathname to determine
whether it should be processed with this plugin.

=item exclude

A regex or code reference which is applied to each full pathname to determine
whether it should be excluded. This overrides C<include> above.

=item options

Options specific to the plugin to be used for its tidying/validation.

=item cache

Optional. A cache object, or a hashref of parameters to pass to L<CHI|CHI> to
construct a cache. If provided, this will be used to ensure that each file is
only processed if it did not change since the last time it was processed.

=back

=item backup_dir

Where to backup files before processing. Defaults to C<data_dir>/backup.

=item cache_dir

A cache directory, used to ensure that files are only processed when they or
the configuration has changed. Defaults to C<data_dir>/cache.

=item data_dir

Default parent directory for C<backup_dir> and C<cache_dir>.

=item recursive

Indcates whether L</process> will follow directories. Defaults to false.

=back
