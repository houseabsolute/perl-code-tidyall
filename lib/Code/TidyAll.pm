package Code::TidyAll;
use Cwd qw(realpath);
use Config::INI::Reader;
use Code::TidyAll::Cache;
use Code::TidyAll::Util qw(basename can_load dirname mkpath read_file write_file);
use Date::Format;
use Digest::SHA1 qw(sha1_hex);
use File::Find qw(find);
use Time::Duration::Parse qw(parse_duration);
use strict;
use warnings;

# Incoming parameters
use Object::Tiny qw(
  backup_ttl
  conf_file
  data_dir
  no_backups
  no_cache
  plugins
  recursive
  root_dir
  verbose
);

# Internal
use Object::Tiny qw(
  backup_dir
  base_sig
  cache
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
        my $main_params = delete( $conf_params->{'_'} ) || {};
        %params = ( plugins => $conf_params, %$main_params, %params );
        $params{root_dir} ||= dirname($conf_file);
    }
    die "conf_file or plugins required"  unless $params{plugins};
    die "conf_file or root_dir required" unless $params{root_dir};

    my $self = $class->SUPER::new(%params);

    $self->{root_dir} = realpath( $self->{root_dir} );
    $self->{data_dir} ||= $self->root_dir . "/.tidyall.d";
    $self->{cache} = Code::TidyAll::Cache->new( cache_dir => $self->data_dir . "/cache" )
      unless $self->no_cache;
    $self->{backup_dir} = $self->data_dir . "/backups";
    $self->{base_sig}   = $self->_sig( [ $Code::TidyAll::VERSION || 0, $self->plugins ] );
    $self->{backup_ttl} = parse_duration( $self->{backup_ttl} || "1 day" );
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

sub process_paths {
    my ( $self, @paths ) = @_;
    foreach my $path (@paths) {
        $self->process_path($path);
    }
}

sub process_path {
    my ( $self, $path ) = @_;
    $path = realpath($path);
    unless ( index( $path, $self->root_dir ) == 0 ) {
        $self->msg( "%s: skipping, not underneath root dir '%s'", $path, $self->root_dir );
        return;
    }

        ( -f $path ) ? $self->_process_file($path)
      : ( -d $path ) ? $self->_process_dir($path)
      :                $self->msg( "%s: not a file or directory\n", $path );
}

sub _process_dir {
    my ( $self, $dir ) = @_;
    unless ( $self->recursive ) {
        $self->msg( "%s: skipping dir, not in recursive mode\n", $dir );
        next;
    }
    next if basename($dir) eq '.tidyall.d';
    my @files;
    find( { follow => 0, wanted => sub { push @files, $_ if -f }, no_chdir => 1 }, $dir );
    foreach my $file (@files) {
        $self->_process_file($file);
    }
}

sub _process_file {
    my ( $self, $file ) = @_;

    my $cache      = $self->cache;
    my $small_path = $self->_small_path($file);
    if ( $self->no_cache
        || ( ( $cache->get("sig/$small_path") || '' ) ne $self->_file_sig($file) ) )
    {
        my $matched = 0;
        foreach my $plugin ( @{ $self->plugin_objects } ) {
            if ( $plugin->matcher->($small_path) ) {
                if ( !$matched++ ) {
                    $self->msg( "%s", $small_path );
                    $self->_backup_file($file);
                }
                $self->msg( "  applying '%s'", $plugin->name ) if $self->verbose;
                eval { $plugin->process_file($file) };
                if ( my $error = $@ ) {
                    $self->msg( "*** '%s': %s", $plugin->name, $error );
                    return;
                }
            }
        }
        $cache->set( "sig/$small_path", $self->_file_sig($file) ) unless $self->no_cache;
    }
}

sub _backup_file {
    my ( $self, $file ) = @_;
    unless ( $self->no_backups ) {
        my $backup_file = join( "/", $self->backup_dir, $self->_backup_filename($file) );
        mkpath( dirname($backup_file), 0, 0775 );
        write_file( $backup_file, read_file($file) );
        if ( my $cache = $self->cache ) {
            my $last_purge_backups = $cache->get("last_purge_backups") || 0;
            if ( time > $last_purge_backups + $self->backup_ttl ) {
                $self->_purge_backups();
                $cache->set( "last_purge_backups", time() );
            }
        }
    }
}

sub _backup_filename {
    my ( $self, $file ) = @_;

    return join( "", $self->_small_path($file), "-", time2str( "%Y%m%d-%H%M%S", time ), ".bak" );
}

sub _purge_backups {
    my ($self) = @_;
    $self->msg("purging old backups") if $self->verbose;
    find(
        {
            follow => 0,
            wanted => sub {
                unlink $_ if -f && /\.bak$/ && time > ( stat($_) )[9] + $self->backup_ttl;
            },
            no_chdir => 1
        },
        $self->backup_dir
    );
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

sub _small_path {
    my ( $self, $path ) = @_;
    die "'%s' is not underneath root dir '%s'!" unless index( $path, $self->root_dir ) == 0;
    return substr( $path, length( $self->root_dir ) + 1 );
}

sub _file_sig {
    my ( $self, $file ) = @_;
    my $last_mod = ( stat($file) )[9];
    my $contents = read_file($file);
    return $self->_sig( [ $self->base_sig, $last_mod, $contents ] );
}

sub _sig {
    my ( $self, $data ) = @_;
    return sha1_hex( join( ",", @$data ) );
}

sub msg {
    my ( $self, $format, @params ) = @_;
    printf( "$format\n", @params );
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

=back

=item cache

A cache object, or a hashref of parameters to pass to L<CHI|CHI> to construct a
cache. This overrides the default cache.

=item data_dir

Data directory for backups and cache.

=item recursive

Indcates whether L</process> will follow directories. Defaults to false.

=back
