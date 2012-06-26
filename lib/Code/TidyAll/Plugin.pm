package Code::TidyAll::Plugin;
use Object::Tiny qw(conf ignore name options root_dir select);
use Code::TidyAll::Util qw(basename read_file tempdir_simple write_file);
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    die "conf required" unless $self->{conf};
    die "name required" unless $self->{name};

    my $name = $self->{name};
    $self->{select} = $self->{conf}->{select}
      or die "select required for '$name'";
    die "select for '$name' should not begin with /" if substr( $self->{select}, 0, 1 ) eq '/';
    $self->{ignore} = $self->{conf}->{ignore};
    die "ignore for '$name' should not begin with /"
      if defined( $self->{ignore} ) && substr( $self->{ignore}, 0, 1 ) eq '/';
    $self->{options} = $self->_build_options();

    return $self;
}

sub process_source_or_file {
    my ( $self, $source, $file ) = @_;

    if ( $self->can('process_source') ) {
        return $self->process_source($source);
    }
    elsif ( $self->can('process_file') ) {
        my $tempfile = join( "/", tempdir_simple(), basename($file) );
        write_file( $tempfile, $source );
        $self->process_file($tempfile);
        return read_file($tempfile);
    }
    else {
        die sprintf( "plugin '%s' must implement either process_file or process_source",
            $self->name );
    }
}

sub _build_options {
    my $self    = shift;
    my %options = %{ $self->{conf} };
    delete( @options{qw(select ignore)} );
    return \%options;
}

1;
