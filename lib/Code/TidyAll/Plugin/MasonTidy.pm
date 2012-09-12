package Code::TidyAll::Plugin::MasonTidy;
use IPC::System::Simple qw(run);
use Moo;
extends 'Code::TidyAll::Plugin';

sub _build_cmd { 'masontidy' }

sub transform_file {
    my ( $self, $file ) = @_;

    run( sprintf( "%s --replace %s %s", $self->cmd, $self->argv, $file ) );
}

1;

__END__

=pod

=head1 NAME

Code::TidyAll::Plugin::MasonTidy - use masontidy with tidyall

=head1 SYNOPSIS

   In tidyall.ini:

   [MasonTidy]
   select = comps/**/*.{mc,mi}
   argv = --indent-perl-block 0 --perltidy-argv "-noll -l=78"

=head1 DESCRIPTION

Runs L<masontidy|masontidy>, a tidier for L<HTML::Mason|HTML::Mason> and
L<Mason 2|Mason> components.

=head1 INSTALLATION

Install L<masontidy|masontidy> from CPAN.

    cpanm masontidy

=head1 CONFIGURATION

=over

=item argv

Arguments to pass to masontidy

=item cmd

Full path to masontidy

=back
