package Code::TidyAll::Plugin;
use Object::Tiny qw(conf ignore matcher name options root_dir select);
use Code::TidyAll::Util qw(read_file write_file);
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    die "conf required" unless $self->{conf};
    die "name required" unless $self->{name};

    my $name = $self->{name};
    $self->{select} = $self->{conf}->{select} or die "select required for '$name'";
    die "select for '$name' should not begin with /" if substr( $self->{select}, 0, 1 ) eq '/';
    $self->{ignore} = $self->{conf}->{ignore};
    die "ignore for '$name' should not begin with /"
      if defined( $self->{ignore} ) && substr( $self->{ignore}, 0, 1 ) eq '/';
    $self->{options} = $self->_build_options();

    return $self;
}

sub process_file {
    my ( $self, $file ) = @_;
    my $source = read_file($file);
    my $dest   = $self->process_source($source);
    write_file( $file, $dest );
}

sub process_source {
    my ( $self, $source ) = @_;
    die sprintf( "plugin '%s' must implement either process_file or process_source", $self->name );
}

sub _build_options {
    my $self    = shift;
    my %options = %{ $self->{conf} };
    delete( @options{qw(select ignore)} );
    return \%options;
}

1;
