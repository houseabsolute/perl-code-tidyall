package Code::TidyAll;
use Moose;
use Method::Signatures::Simple;
use Digest::SHA1 qw(sha1_hex);
use List::Pairwise qw(mapp);

has 'base_sig' => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'cache'    => ( is => 'ro', lazy_build => 1 );
has 'conf'     => ( is => 'ro', lazy_build => 1 );
has 'files'    => ( is => 'ro', lazy_build => 1 );
has 'plugins'  => ( is => 'ro', lazy_build => 1 );
has 'root_dir' => ( is => 'ro', required => 1 );

method tidyall () {
    my $cache = $self->cache;
    foreach my $file ( @{ $self->files } ) {
        if ( -f $file
            && ( $cache->get($file) || '' ) ne $self->_file_sig($file) )
        {
            $self->process_file($file);
            $cache->set( $file, $self->_file_sig($file) );
        }
    }
}

method _build_cache () {
    require CHI;
    return CHI->new(
        driver   => 'File',
        root_dir => $self->root_dir . "/.tidyall_cache"
    );
}

method _build_base_sig () {
    return $self->_sig( [ $Code::TidyAll::VERSION, $self->conf ] );
}

method _build_plugins () {
    return mapp { $self->load_plugin( $a, $b ) } %{ $self->conf->{plugins} };
}

method load_plugin ($plugin_name, $plugin_conf) {
    my $class_name = (
        $plugin_name =~ /^\+/
        ? substr( $plugin_name, 1 )
        : "Code::TidyAll::Plugin::$plugin_name"
    );
    Class::MOP::load_class($class_name);
    return $class_name->new( conf => $plugin_conf, name => $plugin_name );
}

method process_file ($file) {
    foreach my $plugin ( @{ $self->plugins } ) {
        if ( $plugin->matcher->($file) ) {
            $plugin->process_file($file);
        }
    }
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
