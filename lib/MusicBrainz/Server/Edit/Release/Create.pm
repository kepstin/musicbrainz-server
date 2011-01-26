package MusicBrainz::Server::Edit::Release::Create;
use Carp;
use Moose;
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );
use MusicBrainz::Server::Constants qw( $EDIT_RELEASE_CREATE );
use MusicBrainz::Server::Edit::Types qw( 
    ArtistCreditDefinition
    Nullable
    NullableOnPreview
    PartialDateHash );
use MusicBrainz::Server::Edit::Utils qw(
    load_artist_credit_definitions
    artist_credit_from_loaded_definition
);
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit::Generic::Create';
with 'MusicBrainz::Server::Edit::Role::Preview';

sub edit_name { l('Add release') }
sub edit_type { $EDIT_RELEASE_CREATE }
sub _create_model { 'Release' }
sub release_id { shift->entity_id }

has '+data' => (
    isa => Dict[
        name             => Str,
        artist_credit    => ArtistCreditDefinition,
        release_group_id => NullableOnPreview[Int],
        comment          => Nullable[Str],
        date             => Nullable[PartialDateHash],

        barcode          => Nullable[Str],
        country_id       => Nullable[Int],
        language_id      => Nullable[Int],
        packaging_id     => Nullable[Int],
        script_id        => Nullable[Int],
        status_id        => Nullable[Int],
    ]
);

after 'initialize' => sub {
    my $self = shift;

    return if $self->preview;

    croak "No release_group_id specified" unless $self->data->{release_group_id};
};

sub foreign_keys
{
    my $self = shift;
    return {
        Artist           => { load_artist_credit_definitions($self->data->{artist_credit}) },
        ReleaseStatus    => [ $self->data->{status_id} ],
        ReleaseGroup     => [ $self->data->{release_group_id} ],
        Script           => [ $self->data->{script_id} ],
        Language         => [ $self->data->{language_id} ],
    };
}

sub build_display_data
{
    my ($self, $loaded) = @_;

    my $status = $self->data->{status_id};

    return {
        artist_credit => artist_credit_from_loaded_definition($loaded, $self->data->{artist_credit}),
        name          => $self->data->{name},
        comment       => $self->data->{comment},
        status        => $status ? $loaded->{ReleaseStatus}->{ $status } : '',
        script        => $loaded->{Script}{ $self->data->{script_id} },
        language      => $loaded->{Language}{ $self->data->{language_id} },
        barcode       => $self->data->{barcode},
    };
}

sub _insert_hash
{
    my ($self, $data) = @_;
    $data->{artist_credit} = $self->c->model('ArtistCredit')->find_or_insert(@{ $data->{artist_credit} });
    return $data
}

sub _xml_arguments { ForceArray => [ 'artist_credit' ] }

__PACKAGE__->meta->make_immutable;
no Moose;

1;