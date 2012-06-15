package Code::TidyAll;
use Cwd qw(realpath);
use Config::INI::Reader;
use Code::TidyAll::Cache;
use Code::TidyAll::Util
  qw(abs2rel basename can_load dirname dump_one_line mkpath read_dir read_file uniq write_file);
use Date::Format;
use Digest::SHA1 qw(sha1_hex);
use File::Find qw(find);
use File::Zglob;
use Time::Duration::Parse qw(parse_duration);
use Try::Tiny;
use strict;
use warnings;

sub valid_params {
    return qw(
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
}
my %valid_params_hash;

# Incoming parameters
use Object::Tiny ( valid_params() );

# Internal
use Object::Tiny qw(
  backup_dir
  base_sig
  cache
  matched_files
  plugin_objects
);

sub new {
    my $class  = shift;
    my %params = @_;

    # Check param validity
    #
    my $valid_params_hash = $valid_params_hash{$class} ||=
      { map { ( $_, 1 ) } $class->valid_params() };
    if ( my @bad_params = grep { !$valid_params_hash->{$_} } keys(%params) ) {
        die sprintf( "unknown constructor param(s) %s",
            join( ", ", sort map { "'$_'" } @bad_params ) );
    }

    # Read params from conf file
    #
    if ( my $conf_file = $params{conf_file} ) {
        my $conf_params = $class->_read_conf_file($conf_file);
        my $main_params = delete( $conf_params->{'_'} ) || {};
        %params = (
            plugins  => $conf_params,
            root_dir => realpath( dirname($conf_file) ),
            %$main_params, %params
        );
    }
    else {
        die "conf_file or plugins required"  unless $params{plugins};
        die "conf_file or root_dir required" unless $params{root_dir};
    }

    $class->msg( "constructing %s with these params: %s", $class, \%params )
      if ( $params{verbose} );

    my $self = $class->SUPER::new(%params);

    $self->{data_dir} ||= $self->root_dir . "/.tidyall.d";

    unless ( $self->no_cache ) {
        $self->{cache} = Code::TidyAll::Cache->new( cache_dir => $self->data_dir . "/cache" );
    }

    unless ( $self->no_backups ) {
        $self->{backup_dir} = $self->data_dir . "/backups";
        mkpath( $self->backup_dir, 0, 0775 );
        $self->{backup_ttl} ||= '1 hour';
        $self->{backup_ttl} = parse_duration( $self->{backup_ttl} )
          unless $self->{backup_ttl} =~ /^\d+$/;
        $self->_purge_backups_periodically();
    }

    my $plugins = $self->plugins;

    $self->{base_sig} = $self->_sig( [ $Code::TidyAll::VERSION || 0, $plugins ] );
    $self->{plugin_objects} =
      [ map { $self->load_plugin( $_, $plugins->{$_} ) } sort keys( %{ $self->plugins } ) ];
    $self->{matched_files} = $self->_find_matched_files;

    return $self;
}

sub load_plugin {
    my ( $self, $plugin_name, $plugin_conf ) = @_;
    my $class_name = (
        $plugin_name =~ /^\+/
        ? substr( $plugin_name, 1 )
        : "Code::TidyAll::Plugin::$plugin_name"
    );
    try {
        can_load($class_name) || die "not found";
    }
    catch {
        die "could not load plugin class '$class_name': $_";
    };
    return $class_name->new(
        conf => $plugin_conf,
        name => $plugin_name
    );
}

sub process_all {
    my $self = shift;

    $self->process_files( keys( %{ $self->matched_files } ) );
}

sub process_files {
    my ( $self, @files ) = @_;
    foreach my $file (@files) {
        $self->_process_file($file);
    }
}

sub _process_file {
    my ( $self, $file ) = @_;

    my @plugins    = @{ $self->matched_files->{$file} || [] };
    my $small_path = $self->_small_path($file);
    if ( !@plugins ) {
        $self->msg( "[no plugins apply] %s", $small_path );
    }

    my $cache = $self->cache;
    my $error;
    my $orig_contents = read_file($file);
    if ( $cache && ( my $sig = $cache->get("sig/$small_path") ) ) {
        return if $sig eq $self->_file_sig( $file, $orig_contents );
    }

    foreach my $plugin (@plugins) {
        try {
            $plugin->process_file($file);
        }
        catch {
            $error = sprintf( "*** '%s': %s", $plugin->name, $_ );
        };
        last if $error;
    }

    my $new_contents = read_file($file);
    my $was_tidied   = $orig_contents ne $new_contents;
    my $status       = $was_tidied ? "[tidied]  " : "[checked] ";
    my $plugin_names =
      $self->verbose ? sprintf( " (%s)", join( ", ", map { $_->name } @plugins ) ) : "";
    $self->msg( "%s%s%s", $status, $small_path, $plugin_names );
    $self->_backup_file( $file, $orig_contents ) if $was_tidied;

    if ($error) {
        $self->msg( "%s", $error );
    }
    else {
        $cache->set( "sig/$small_path", $self->_file_sig( $file, $new_contents ) ) if $cache;
    }
}

sub _read_conf_file {
    my ( $class, $conf_file ) = @_;
    my $conf_string = read_file($conf_file);
    my $root_dir    = basename($conf_file);
    $conf_string =~ s/\$ROOT/$root_dir/g;
    my $conf_hash = Config::INI::Reader->read_string($conf_string);
    die "'$conf_file' did not evaluate to a hash"
      unless ( ref($conf_hash) eq 'HASH' );
    return $conf_hash;
}

sub _backup_file {
    my ( $self, $file, $contents ) = @_;
    unless ( $self->no_backups ) {
        my $backup_file = join( "/", $self->backup_dir, $self->_backup_filename($file) );
        mkpath( dirname($backup_file), 0, 0775 );
        write_file( $backup_file, $contents );
    }
}

sub _backup_filename {
    my ( $self, $file ) = @_;

    return join( "", $self->_small_path($file), "-", time2str( "%Y%m%d-%H%M%S", time ), ".bak" );
}

sub _purge_backups_periodically {
    my ($self) = @_;
    if ( my $cache = $self->cache ) {
        my $last_purge_backups = $cache->get("last_purge_backups") || 0;
        if ( time > $last_purge_backups + $self->backup_ttl ) {
            $self->_purge_backups();
            $cache->set( "last_purge_backups", time() );
        }
    }
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

sub find_conf_file {
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

sub _find_matched_files {
    my ($self) = @_;

    my %matched_files;
    foreach my $plugin ( @{ $self->plugin_objects } ) {
        my @selected = $self->_zglob( $plugin->select );
        if ( defined( $plugin->ignore ) ) {
            my %is_ignored = map { ( $_, 1 ) } $self->_zglob( $plugin->ignore );
            @selected = grep { !$is_ignored{$_} } @selected;
        }
        foreach my $file (@selected) {
            $matched_files{$file} ||= [];
            push( @{ $matched_files{$file} }, $plugin );
        }
    }
    return \%matched_files;
}

sub _zglob {
    my ( $self, $expr ) = @_;

    return File::Zglob::zglob( join( "/", $self->root_dir, $expr ) );
}

sub _small_path {
    my ( $self, $path ) = @_;
    die sprintf( "'%s' is not underneath root dir '%s'!", $path, $self->root_dir )
      unless index( $path, $self->root_dir ) == 0;
    return substr( $path, length( $self->root_dir ) + 1 );
}

sub _file_sig {
    my ( $self, $file, $contents ) = @_;
    my $last_mod = ( stat($file) )[9];
    $contents = read_file($file) if !defined($contents);
    return $self->_sig( [ $self->base_sig, $last_mod, $contents ] );
}

sub _sig {
    my ( $self, $data ) = @_;
    return sha1_hex( join( ",", @$data ) );
}

sub msg {
    my ( $self, $format, @params ) = @_;
    @params = map { ref($_) ? dump_one_line($_) : $_ } @params;
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
        conf_file => '/path/to/conf/file'
    );

    # or

    my $ct = Code::TidyAll->new(
        root_dir => '/path/to/root',
        plugins  => {
            perltidy => {
                select => qr/\.(pl|pm|t)$/,
                options => { argv => '-noll -it=2' },
            },
            perlcritic => {
                select => qr/\.(pl|pm|t)$/,
                options => { '-include' => ['layout'], '-severity' => 3, }
            }
        }
    );
    $ct->process_paths($path1, $path2);

=head1 DESCRIPTION

This is the engine used by L<tidyall|tidyall>, which you can use from your
own program instead of calling C<tidyall>.

=head1 CONSTRUCTOR OPTIONS

These options are the same as the equivalents in C<tidyall>, replacing dashes
with underscore (e.g. the C<backup-ttl> option becomes C<backup_ttl> here).

=over

=item backup_ttl

=item conf_file

=item data_dir

=item no_backups

=item no_cache

=item plugins

=item recursive

=item root_dir

=item verbose

=back
