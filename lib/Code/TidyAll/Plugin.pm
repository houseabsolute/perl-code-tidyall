package Code::TidyAll::Plugin;
use Code::TidyAll::Util qw(read_file write_file);
use Moose;
use Method::Signatures::Simple;

has 'conf'     => ( is => 'ro', required => 1 );
has 'exclude'  => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'include'  => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'matcher'  => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'name'     => ( is => 'ro', required => 1 );
has 'options'  => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'root_dir' => ( is => 'ro' );

method defaults () { return {} }

method process_file ($file) {
    my $source = read_file($file);
    my $dest   = $self->process_source($source);
    write_file( $file, $dest );
}

method _build_matcher () {
    my $conf = $self->conf;

    my $include = $self->_match_spec_to_coderef( 'include', $self->include );
    my $exclude = $self->_match_spec_to_coderef( 'exclude', $self->exclude );

    return sub { my $file = shift; return $include->($file) && !$exclude->($file) };
}

method _build_include () {
    return
         $self->conf->{include}
      || $self->defaults->{include}
      || die sprintf( "cannot determine include condition for plugin '%s'", $self->name );
}

method _build_exclude () {
    return $self->conf->{exclude} || $self->defaults->{exclude} || sub { 0 };
}

method _build_options () {
    my %options = %{ $self->{conf} };
    delete( @options{qw(include exclude)} );
    return \%options;
}

method _match_spec_to_coderef ($type, $spec) {
    $spec = qr/$spec/ if ( !ref($spec) );
    if ( ref($spec) eq 'Regexp' ) {
        return sub { $_[0] =~ $spec };
    }
    elsif ( ref($spec) eq 'CODE' ) {
        return $spec;
    }
    else {
        die sprintf( "bad '%s' conf value for plugin '%s': '%s'", $type, $self->name, $spec );
    }
}

1;
