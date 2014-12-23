package inc::Pod::Weaver::Section::SeeAlsoCodeTidyAll;

use namespace::autoclean;

use Moose;
with 'Pod::Weaver::Role::Section';

use Moose::Autobox;
use Pod::Elemental::Selectors;

# Add "SEE ALSO: Code::TidyAll"

sub weave_section {
    my ( $self, $document, $input ) = @_;

    return if $input->{filename} =~ m{\QCode/TidyAll.pm};

    my $idc = $input->{pod_document}->children;
    for ( my $i = 0 ; $i < $idc->length ; $i++ ) {
        next unless my $para = $idc->[$i];
        return
             if $para->can('command')
          && $para->command eq 'head1'
          && $para->content eq 'SEE ALSO';
    }
    $document->children->push(
        Pod::Elemental::Element::Nested->new(
            {
                command  => 'head1',
                content  => 'SEE ALSO',
                children => [
                    Pod::Elemental::Element::Pod5::Ordinary->new(
                        { content => "L<Code::TidyAll>" }
                    ),
                ],
            }
        ),
    );
}

__PACKAGE__->meta->make_immutable;

1;
