package Code::TidyAll;
use Cwd qw(realpath);
use Config::INI::Reader;
use Code::TidyAll::Cache;
use Code::TidyAll::Util qw(can_load dirname mkpath read_file write_file);
use Date::Format;
use Digest::SHA1 qw(sha1_hex);
use File::Find qw(find);
use Time::Duration::Parse qw(parse_duration);
use strict;
use warnings;

# Incoming parameters
use Object::Tiny qw(
  backup_purge
  cache
  conf_file
  data_dir
  no_backups
  no_cache
  plugins
  recursive
  verbose
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
        my $main_params = delete( $conf_params->{'_'} ) || {};
        %params = ( plugins => $conf_params, %$main_params, %params );
        $params{data_dir} ||= join( "/", dirname($conf_file), ".tidyall.d" );
    }

    my $self = $class->SUPER::new(%params);
    die "conf_file or plugins required"  unless $self->{plugins};
    die "conf_file or data_dir required" unless $self->{data_dir};

    $self->{cache} ||= Code::TidyAll::Cache->new( cache_dir => $self->data_dir . "/cache" )
      unless $self->no_cache;
    $self->{base_sig} = $self->_sig( [ $Code::TidyAll::VERSION || 0, $self->plugins ] );
    $self->{backup_purge} = parse_duration( $self->{backup_purge} || "1 day" );

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
    if ( !$cache || ( ( $cache->get("sig/$file") || '' ) ne $self->_file_sig($file) ) ) {
        my $matched = 0;
        foreach my $plugin ( @{ $self->plugin_objects } ) {
            if ( $plugin->matcher->($file) ) {
                if ( !$matched++ ) {
                    print "$file\n";
                    $self->backup_file($file);
                }
                eval { $plugin->process_file($file) };
                if ( my $error = $@ ) {
                    printf STDERR "*** '%s': %s\n", $plugin->name, $error;
                    return;
                }
            }
        }
        $cache->set( "sig/$file", $self->_file_sig($file) ) if $cache;
    }
}

sub backup_file {
    my ( $self, $file ) = @_;
    unless ( $self->no_backups ) {
        my $backup_file = join( "",
            $self->data_dir, "/backups", realpath($file), "-",
            time2str( "%Y-%m-%d-%H-%M-%S", time ) );
        mkpath( dirname($backup_file), 0, 0775 );
        write_file( $backup_file, read_file($file) );
    }
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
    return sha1_hex( join( ",", @$data ) );
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
