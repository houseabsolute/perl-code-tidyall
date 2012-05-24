package Code::TidyAll;
use CHI;
use Moose;
use File::Find qw(find);
use Code::TidyAll::Util qw(can_load read_file);
use Method::Signatures::Simple;
use Digest::SHA1 qw(sha1_hex);
use List::Pairwise qw(mapp);
use JSON::XS qw(encode_json);

has 'base_sig'       => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'cache'          => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'cache_dir'      => ( is => 'ro', lazy_build => 1 );
has 'plugin_objects' => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'plugins'        => ( is => 'ro', required => 1 );
has 'root_dir'       => ( is => 'ro', required => 1 );

method tidyall () {
    my $cache = $self->cache;
    my @files;
    find( { wanted => sub { push @files, $_ if -f }, no_chdir => 1 }, $self->root_dir );
    foreach my $file (@files) {
        if ( ( $cache->get($file) || '' ) ne $self->_file_sig($file) ) {
            if ( $self->process_file($file) ) {
                $cache->set( $file, $self->_file_sig($file) );
            }
        }
    }
}

method _build_cache () {
    return CHI->new( driver => 'File', root_dir => $self->cache_dir );
}

method _build_cache_dir () {
    return $self->root_dir . "/.tidyall_cache";
}

method _build_base_sig () {
    return $self->_sig( [ $Code::TidyAll::VERSION, $self->plugins ] );
}

method _build_plugin_objects () {
    return [ mapp { $self->load_plugin( $a, $b ) } %{ $self->plugins } ];
}

method load_plugin ($plugin_name, $plugin_conf) {
    my $class_name = (
        $plugin_name =~ /^\+/
        ? substr( $plugin_name, 1 )
        : "Code::TidyAll::Plugin::$plugin_name"
    );
    if ( can_load($class_name) ) {
        return $class_name->new(
            conf     => $plugin_conf,
            name     => $plugin_name,
            root_dir => $self->root_dir
        );
    }
    else {
        die "could not load plugin class '$class_name'";
    }
}

method process_file ($file) {
    my $matched = 0;
    foreach my $plugin ( @{ $self->plugin_objects } ) {
        if ( $plugin->matcher->($file) ) {
            print "$file\n" if !$matched++;
            eval { $plugin->process_file($file) };
            if ( my $error = $@ ) {
                printf( "*** '%s': %s", $plugin->name, $error );
                return 0;
            }
        }
    }
    return 1;
}

method _file_sig ($file) {
    my $last_mod = ( stat($file) )[9];
    my $contents = read_file($file);
    return $self->_sig( [ $self->base_sig, $last_mod, $contents ] );
}

method _sig ($data) {
    return sha1_hex( encode_json($data) );
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll - Tidy and validate code in many ways at once

=head1 SYNOPSIS

    use Code::TidyAll;

    my $ct = Code::TidyAll->new(
        root_dir => '...',
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
    $ct->tidyall;

=head1 DESCRIPTION

=head1 CONSTRUCTOR OPTIONS

=over

=item root_dir

Required. All files under the root directory and its subdirectories will be
considered for processing.

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

=over

=item 

=item 

=back
