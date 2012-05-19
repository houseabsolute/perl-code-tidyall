package Code::TidyAll::Plugin;
use Moose;
use Method::Signatures::Simple;

has 'conf'    => ( is => 'ro', required => 1 );
has 'matcher' => ( is => 'ro', init_arg => undef, lazy_build => 1 );
has 'name'    => ( is => 'ro', required => 1 );

method process_file ($file) {
    my $source = read_file($file);
    my $dest   = $self->process_source($source);
    write_file( $file, $dest );
}

method _build_matcher () {
    my $conf = $self->conf;

    my $include = $conf->{include}
      || die "no include configured for plugin " . $self->name;
    my $exclude = $conf->{include} || sub { 0 };
    $include = _match_spec_to_coderef( 'include', $include );
    $exclude = _match_spec_to_coderef( 'exclude', $exclude );

    return sub {
        $include->($file) && !$exclude->($file);
    };
}

func _match_spec_to_coderef ($type, $spec) {
    $spec = qr/$spec/ if ( !ref($spec) );
    if ( ref($spec) eq 'Regexp' ) {
        $coderef{$type} = sub { $_[0] =~ $spec };
    }
    elsif ( ref($spec) eq 'CODE' ) {
        $coderef{$type} = $spec;
    }
    else {
        die sprintf( "bad '%s' conf value for plugin '%s': '%s'", $type, $self->name, $spec );
    }
}

1;
