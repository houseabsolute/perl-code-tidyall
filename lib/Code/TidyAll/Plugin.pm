package Code::TidyAll::Plugin;
use Object::Tiny qw(conf exclude include matcher name options root_dir);
use Code::TidyAll::Util qw(read_file write_file);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    die "conf required" unless $self->{conf};
    die "name required" unless $self->{name};

    $self->{include} = $self->_build_include();
    $self->{exclude} = $self->_build_exclude();
    $self->{matcher} = $self->_build_matcher();
    $self->{options} = $self->_build_options();

    return $self;
}

sub defaults { return {} }

sub process_file {
    my ( $self, $file ) = @_;
    my $source = read_file($file);
    my $dest   = $self->process_source($source);
    write_file( $file, $dest );
}

sub _build_matcher {
    my $self = shift;
    my $conf = $self->conf;

    my $include = $self->_match_spec_to_coderef( 'include', $self->include );
    my $exclude = $self->_match_spec_to_coderef( 'exclude', $self->exclude );

    return sub { my $file = shift; return $include->($file) && !$exclude->($file) };
}

sub _build_include {
    my $self = shift;
    return
         $self->conf->{include}
      || $self->defaults->{include}
      || die sprintf( "cannot determine include condition for plugin '%s'", $self->name );
}

sub _build_exclude {
    my $self = shift;
    return $self->conf->{exclude} || $self->defaults->{exclude} || sub { 0 };
}

sub _build_options {
    my $self    = shift;
    my %options = %{ $self->{conf} };
    delete( @options{qw(include exclude)} );
    return \%options;
}

sub _match_spec_to_coderef {
    my ( $self, $type, $spec ) = @_;
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
