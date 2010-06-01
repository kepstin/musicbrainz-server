package MusicBrainz::Server::Edit::Historic::RemoveRelease;
use Moose;
use MooseX::Types::Structured qw( Dict );
use MooseX::Types::Moose qw( ArrayRef Int Str );

use aliased 'MusicBrainz::Server::Entity::ArtistCredit';
use aliased 'MusicBrainz::Server::Entity::ArtistCreditName';
use aliased 'MusicBrainz::Server::Entity::Release';

use MusicBrainz::Server::Constants qw( $EDIT_HISTORIC_REMOVE_RELEASE );

extends 'MusicBrainz::Server::Edit::Historic';
with 'MusicBrainz::Server::Edit::Historic::NoSerialization';

sub edit_name     { 'Remove release' }
sub historic_type { 12 }
sub edit_type     { $EDIT_HISTORIC_REMOVE_RELEASE }

sub related_entities
{
    my $self = shift;
    return {
        release => $self->data->{release_ids}
    }
}

has '+data' => (
    isa => Dict[
        release_ids => ArrayRef[Int],
        name        => Str,
        artist_id   => Int
    ]
);

sub foreign_keys
{
    my $self = shift;
    return {
        Release => { map { $_ => [ 'ArtistCredit' ] } @{ $self->data->{release_ids} } },
        Artist  => [ $self->data->{artist_id} ]
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;

    my $data = {
        name     => $self->data->{name},
        releases => [
            map {
                $loaded->{Release}->{$_} || Release->new( name => $self->data->{name} )
            } @{ $self->data->{release_ids} }
        ]
    };

    if (my $artist = $loaded->{Artist}->{ $self->data->{artist_id} }) {
        $data->{artist_credit} = ArtistCredit->new( names => [
            ArtistCreditName->new(
                name   => $artist->name,
                artist => $artist
            )
        ]);
    }

    return $data;
}

sub upgrade
{
    my $self = shift;
    $self->data({
        release_ids => $self->album_release_ids($self->row_id),
        name        => $self->previous_value,
        artist_id   => $self->artist_id,
    });

    return $self;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
